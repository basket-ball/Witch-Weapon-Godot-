import { successResponse, errorResponse, forbiddenResponse, notFoundResponse } from '../utils/response.js';

const DEFAULT_MAX_FILE_SIZE = 50 * 1024 * 1024;
const MAX_LIST_LIMIT = 50;
const ALLOWED_FILE_TYPES = new Set(['zip', 'rar', '7z']);

export async function uploadMod(request, env, user) {
  if (!env.MOD_FILES) {
    return errorResponse('MOD_FILES bucket is not configured on this worker', 500);
  }

  const schemaError = await ensureModsSchema(env);
  if (schemaError) {
    return schemaError;
  }

  const contentType = (request.headers.get('Content-Type') || '').toLowerCase();
  if (!contentType.includes('multipart/form-data')) {
    return errorResponse('Use multipart/form-data with a `file` field');
  }

  let formData;
  try {
    formData = await request.formData();
  } catch {
    return errorResponse('Invalid multipart form body');
  }

  const uploadFile = formData.get('file');
  if (!uploadFile || typeof uploadFile === 'string' || typeof uploadFile.arrayBuffer !== 'function') {
    return errorResponse('Field `file` is required');
  }

  const fileName = typeof uploadFile.name === 'string' && uploadFile.name ? uploadFile.name : 'mod-package.zip';
  const fileSize = Number(uploadFile.size || 0);
  const fileType = getFileExtension(fileName);

  if (!ALLOWED_FILE_TYPES.has(fileType)) {
    return errorResponse('Only zip/rar/7z packages are allowed');
  }

  const maxFileSize = getMaxUploadSize(env);
  if (fileSize <= 0 || fileSize > maxFileSize) {
    return errorResponse(`Package size must be between 1 byte and ${maxFileSize} bytes`);
  }

  let metadata = {};
  const metadataRaw = formData.get('metadata');
  if (typeof metadataRaw === 'string' && metadataRaw.trim()) {
    try {
      metadata = JSON.parse(metadataRaw);
    } catch {
      return errorResponse('Field `metadata` must be valid JSON');
    }

    if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
      return errorResponse('Field `metadata` must be a JSON object');
    }
  }

  const modConfigRaw = formData.get('mod_config');
  let providedModConfig = null;
  if (typeof modConfigRaw === 'string' && modConfigRaw.trim()) {
    try {
      providedModConfig = JSON.parse(modConfigRaw);
    } catch {
      return errorResponse('Field `mod_config` must be valid JSON');
    }
  }

  const fileBuffer = await uploadFile.arrayBuffer();
  let zipEntries = [];
  if (fileType === 'zip') {
    try {
      zipEntries = parseZipEntries(fileBuffer);
    } catch (error) {
      return errorResponse(`Invalid ZIP package: ${error.message}`);
    }
  }

  let packageModConfig = null;
  if (fileType === 'zip') {
    const modConfigEntry = zipEntries.find((entry) => isModConfigPath(entry.fileName));
    if (!modConfigEntry) {
      return errorResponse('ZIP package must include mod_config.json');
    }

    try {
      const modConfigBytes = await readZipEntryBytes(fileBuffer, modConfigEntry);
      packageModConfig = JSON.parse(new TextDecoder().decode(modConfigBytes));
    } catch (error) {
      return errorResponse(`Failed to read mod_config.json from ZIP: ${error.message}`);
    }
  } else if (!providedModConfig) {
    return errorResponse('RAR/7z upload must provide `mod_config` JSON in form data');
  }

  const sourceModConfig = packageModConfig || providedModConfig || {};
  const normalizedModConfig = normalizeModConfig(sourceModConfig, formData, fileName, user);

  if (Object.keys(normalizedModConfig.episodes).length === 0) {
    return errorResponse('mod_config.episodes cannot be empty');
  }

  if (fileType === 'zip') {
    const missingEpisodeFiles = Object.values(normalizedModConfig.episodes).filter(
      (path) => !hasZipPath(zipEntries, path)
    );

    if (missingEpisodeFiles.length > 0) {
      return errorResponse(`ZIP package is missing episode scenes: ${missingEpisodeFiles.join(', ')}`);
    }
  }

  const fileHash = await sha256Hex(fileBuffer);
  const duplicate = await env.DB.prepare(
    'SELECT id, mod_slug FROM mods WHERE user_id = ? AND file_hash = ? LIMIT 1'
  ).bind(user.user_id, fileHash).first();

  if (duplicate) {
    return errorResponse(`This package is already uploaded as slug ${duplicate.mod_slug}`, 409, 'MOD_DUPLICATE');
  }

  const slugCandidate =
    readTextField(formData, 'mod_slug') ||
    normalizedModConfig.mod_id ||
    normalizedModConfig.title ||
    fileName;
  const modSlug = await allocateModSlug(env, slugCandidate);

  const objectKey = buildObjectKey(user.user_id, modSlug, normalizedModConfig.version, fileType);

  await env.MOD_FILES.put(objectKey, fileBuffer, {
    httpMetadata: {
      contentType: contentTypeByExtension(fileType),
    },
    customMetadata: {
      mod_slug: modSlug,
      uploader_id: String(user.user_id),
      file_hash: fileHash,
    },
  });

  const mergedMetadata = {
    ...metadata,
    format: 'witch-weapon-editor-v1',
    upload_filename: fileName,
    uploaded_at: new Date().toISOString(),
    episode_count: Object.keys(normalizedModConfig.episodes).length,
    mod_config: normalizedModConfig,
  };

  const authorName =
    normalizedModConfig.author || readTextField(formData, 'author_name') || user.email.split('@')[0] || 'unknown';

  const insertResult = await env.DB.prepare(
    `INSERT INTO mods (
      user_id,
      author_name,
      mod_name,
      mod_slug,
      description,
      version,
      file_path,
      file_size,
      file_hash,
      file_type,
      metadata,
      status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`
  ).bind(
    user.user_id,
    authorName,
    normalizedModConfig.title,
    modSlug,
    normalizedModConfig.description,
    normalizedModConfig.version,
    objectKey,
    fileSize,
    fileHash,
    fileType,
    JSON.stringify(mergedMetadata)
  ).run();

  const modId = Number(insertResult?.meta?.last_row_id || 0);

  await insertModVersionIfAvailable(env, {
    modId,
    version: normalizedModConfig.version,
    filePath: objectKey,
    fileSize,
    fileHash,
    changelog: typeof mergedMetadata.changelog === 'string' ? mergedMetadata.changelog : null,
  });

  return successResponse(
    {
      id: modId,
      slug: modSlug,
      status: 0,
      mod_name: normalizedModConfig.title,
      version: normalizedModConfig.version,
      file_size: fileSize,
      file_type: fileType,
      file_hash: fileHash,
    },
    'Mod uploaded successfully and is pending review'
  );
}

export async function listMods(request, env) {
  const schemaError = await ensureModsSchema(env);
  if (schemaError) {
    return schemaError;
  }

  const url = new URL(request.url);
  const page = clampInt(url.searchParams.get('page'), 1, 1, 1000000);
  const limit = clampInt(url.searchParams.get('limit'), 20, 1, MAX_LIST_LIMIT);
  const offset = (page - 1) * limit;

  const q = (url.searchParams.get('q') || '').trim();
  const sort = (url.searchParams.get('sort') || 'new').toLowerCase();
  const orderBy = getOrderBy(sort);

  const whereParts = ['status = 1'];
  const params = [];

  if (q) {
    whereParts.push('(mod_name LIKE ? OR author_name LIKE ? OR description LIKE ?)');
    const like = `%${q}%`;
    params.push(like, like, like);
  }

  const whereClause = whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';

  const modsResult = await env.DB.prepare(
    `SELECT
      id,
      user_id,
      author_name,
      mod_name,
      mod_slug,
      description,
      version,
      file_size,
      file_type,
      metadata,
      status,
      review_note,
      reviewed_by,
      reviewed_at,
      download_count,
      view_count,
      rating_score,
      rating_count,
      created_at,
      updated_at,
      published_at
     FROM mods
     ${whereClause}
     ORDER BY ${orderBy}
     LIMIT ? OFFSET ?`
  ).bind(...params, limit, offset).all();

  const countResult = await env.DB.prepare(
    `SELECT COUNT(*) AS total FROM mods ${whereClause}`
  ).bind(...params).first();

  const total = Number(countResult?.total || 0);

  return successResponse({
    mods: (modsResult.results || []).map((row) => formatModRow(row, { includeReview: false, includeFilePath: false })),
    pagination: {
      page,
      limit,
      total,
      total_pages: Math.max(1, Math.ceil(total / limit)),
    },
  });
}

export async function getModDetail(request, env) {
  const schemaError = await ensureModsSchema(env);
  if (schemaError) {
    return schemaError;
  }

  const path = new URL(request.url).pathname;
  const modSlug = decodeURIComponent(path.replace(/^\/api\/mods\//, '')).trim();

  if (!modSlug) {
    return notFoundResponse('Mod not found');
  }

  const mod = await env.DB.prepare(
    `SELECT
      id,
      user_id,
      author_name,
      mod_name,
      mod_slug,
      description,
      version,
      file_size,
      file_type,
      metadata,
      status,
      review_note,
      reviewed_by,
      reviewed_at,
      download_count,
      view_count,
      rating_score,
      rating_count,
      created_at,
      updated_at,
      published_at
     FROM mods
     WHERE mod_slug = ? AND status = 1
     LIMIT 1`
  ).bind(modSlug).first();

  if (!mod) {
    return notFoundResponse('Mod not found');
  }

  await env.DB.prepare('UPDATE mods SET view_count = view_count + 1 WHERE id = ?').bind(mod.id).run();

  const data = formatModRow(mod, { includeReview: false, includeFilePath: false });
  data.view_count = Number(data.view_count || 0) + 1;
  return successResponse(data);
}

export async function getMyMods(request, env, user) {
  const schemaError = await ensureModsSchema(env);
  if (schemaError) {
    return schemaError;
  }

  const url = new URL(request.url);
  const page = clampInt(url.searchParams.get('page'), 1, 1, 1000000);
  const limit = clampInt(url.searchParams.get('limit'), 20, 1, MAX_LIST_LIMIT);
  const offset = (page - 1) * limit;

  const statusValue = url.searchParams.get('status');
  const whereParts = ['user_id = ?'];
  const params = [user.user_id];

  if (statusValue !== null && statusValue !== '') {
    const status = Number(statusValue);
    if (!Number.isInteger(status) || status < 0 || status > 3) {
      return errorResponse('status must be an integer in [0, 3]');
    }
    whereParts.push('status = ?');
    params.push(status);
  }

  const whereClause = `WHERE ${whereParts.join(' AND ')}`;

  const modsResult = await env.DB.prepare(
    `SELECT
      id,
      user_id,
      author_name,
      mod_name,
      mod_slug,
      description,
      version,
      file_path,
      file_size,
      file_type,
      metadata,
      status,
      review_note,
      reviewed_by,
      reviewed_at,
      download_count,
      view_count,
      rating_score,
      rating_count,
      created_at,
      updated_at,
      published_at
     FROM mods
     ${whereClause}
     ORDER BY created_at DESC
     LIMIT ? OFFSET ?`
  ).bind(...params, limit, offset).all();

  const countResult = await env.DB.prepare(
    `SELECT COUNT(*) AS total FROM mods ${whereClause}`
  ).bind(...params).first();

  const total = Number(countResult?.total || 0);

  return successResponse({
    mods: (modsResult.results || []).map((row) => formatModRow(row, { includeReview: true, includeFilePath: true })),
    pagination: {
      page,
      limit,
      total,
      total_pages: Math.max(1, Math.ceil(total / limit)),
    },
  });
}

export async function reviewMod(request, env, admin) {
  if (admin.role !== 'admin') {
    return forbiddenResponse('Only admins can review mods');
  }

  const schemaError = await ensureModsSchema(env);
  if (schemaError) {
    return schemaError;
  }

  const path = new URL(request.url).pathname;
  const match = path.match(/^\/api\/admin\/mods\/(\d+)\/review$/);
  if (!match) {
    return notFoundResponse('Mod not found');
  }

  const modId = Number(match[1]);
  let payload;
  try {
    payload = await request.json();
  } catch {
    return errorResponse('Invalid JSON body');
  }

  const status = Number(payload?.status);
  if (!Number.isInteger(status) || status < 0 || status > 3) {
    return errorResponse('status must be an integer in [0, 3]');
  }

  const reviewNote = typeof payload?.review_note === 'string' ? payload.review_note.trim() : null;

  const mod = await env.DB.prepare(
    'SELECT id, status, published_at FROM mods WHERE id = ? LIMIT 1'
  ).bind(modId).first();

  if (!mod) {
    return notFoundResponse('Mod not found');
  }

  const now = Math.floor(Date.now() / 1000);
  let publishedAt = mod.published_at;
  if (status === 1 && !publishedAt) {
    publishedAt = now;
  }
  if (status === 0 || status === 3) {
    publishedAt = null;
  }

  await env.DB.prepare(
    `UPDATE mods
     SET status = ?, review_note = ?, reviewed_by = ?, reviewed_at = ?, published_at = ?
     WHERE id = ?`
  ).bind(status, reviewNote, admin.user_id, now, publishedAt, modId).run();

  return successResponse({
    id: modId,
    old_status: mod.status,
    status,
    review_note: reviewNote,
    reviewed_by: admin.user_id,
    reviewed_at: now,
    published_at: publishedAt,
  }, 'Mod review updated');
}

export async function downloadMod(request, env) {
  if (!env.MOD_FILES) {
    return errorResponse('MOD_FILES bucket is not configured on this worker', 500);
  }

  const schemaError = await ensureModsSchema(env);
  if (schemaError) {
    return schemaError;
  }

  const path = new URL(request.url).pathname;
  const match = path.match(/^\/api\/mods\/(\d+)\/download$/);
  if (!match) {
    return notFoundResponse('Mod not found');
  }

  const modId = Number(match[1]);
  const mod = await env.DB.prepare(
    `SELECT
      id,
      mod_name,
      mod_slug,
      version,
      file_path,
      file_type,
      status
     FROM mods
     WHERE id = ? AND status = 1
     LIMIT 1`
  ).bind(modId).first();

  if (!mod) {
    return notFoundResponse('Mod not found');
  }

  const object = await env.MOD_FILES.get(mod.file_path);
  if (!object) {
    return notFoundResponse('Package file does not exist in storage');
  }

  await env.DB.prepare('UPDATE mods SET download_count = download_count + 1 WHERE id = ?').bind(modId).run();
  await insertDownloadLogIfAvailable(env, request, modId);

  const extension = String(mod.file_type || 'zip').toLowerCase();
  const downloadName = `${slugify(mod.mod_slug || mod.mod_name || 'mod')}-v${safeFileToken(mod.version || '1.0.0')}.${extension}`;

  const headers = new Headers();
  headers.set('Content-Type', contentTypeByExtension(extension));
  headers.set('Content-Disposition', `attachment; filename="${downloadName}"`);
  headers.set('Cache-Control', 'no-cache');

  return new Response(object.body, { status: 200, headers });
}

function formatModRow(row, { includeReview, includeFilePath }) {
  const metadata = safeParseObject(row.metadata);
  const base = {
    id: Number(row.id),
    user_id: Number(row.user_id),
    author_name: row.author_name,
    mod_name: row.mod_name,
    mod_slug: row.mod_slug,
    description: row.description,
    version: row.version,
    file_size: Number(row.file_size || 0),
    file_type: row.file_type,
    metadata,
    status: Number(row.status),
    download_count: Number(row.download_count || 0),
    view_count: Number(row.view_count || 0),
    rating_score: Number(row.rating_score || 0),
    rating_count: Number(row.rating_count || 0),
    created_at: Number(row.created_at || 0),
    updated_at: Number(row.updated_at || 0),
    published_at: row.published_at === null || row.published_at === undefined ? null : Number(row.published_at),
  };

  if (includeReview) {
    base.review_note = row.review_note;
    base.reviewed_by = row.reviewed_by === null || row.reviewed_by === undefined ? null : Number(row.reviewed_by);
    base.reviewed_at = row.reviewed_at === null || row.reviewed_at === undefined ? null : Number(row.reviewed_at);
  }

  if (includeFilePath) {
    base.file_path = row.file_path;
  }

  return base;
}

function safeParseObject(raw) {
  if (typeof raw !== 'string' || !raw.trim()) {
    return {};
  }

  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return {};
    }
    return parsed;
  } catch {
    return {};
  }
}

function normalizeModConfig(config, formData, fileName, user) {
  const source = config && typeof config === 'object' && !Array.isArray(config) ? config : {};

  const title =
    readTextField(formData, 'mod_name') ||
    safeTrim(source.title) ||
    stripExtension(fileName) ||
    'untitled-mod';

  const modId =
    readTextField(formData, 'mod_id') ||
    readTextField(formData, 'mod_slug') ||
    safeTrim(source.mod_id) ||
    title;

  const version =
    readTextField(formData, 'version') ||
    safeTrim(source.version) ||
    '1.0.0';

  const description =
    readTextField(formData, 'description') ||
    safeTrim(source.description) ||
    '';

  const author =
    safeTrim(source.author) ||
    readTextField(formData, 'author_name') ||
    user.email.split('@')[0] ||
    'unknown';

  const previewImage = safeTrim(source.preview_image) || 'icon.png';
  const episodes = normalizeEpisodes(source.episodes);

  return {
    mod_id: modId,
    title,
    author,
    version,
    description,
    preview_image: previewImage,
    episodes,
  };
}

function normalizeEpisodes(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }

  const entries = Object.entries(value);
  const output = {};

  for (const [rawTitle, rawPath] of entries) {
    const title = safeTrim(rawTitle);
    const path = safeTrim(rawPath);
    if (!title || !path) {
      continue;
    }

    const normalizedPath = path.replace(/\\/g, '/').replace(/^\.\//, '').replace(/^\//, '');
    output[title] = normalizedPath;
  }

  return output;
}

function readTextField(formData, fieldName) {
  const value = formData.get(fieldName);
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function safeTrim(value) {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function stripExtension(name) {
  const trimmed = safeTrim(name);
  if (!trimmed) {
    return '';
  }
  const idx = trimmed.lastIndexOf('.');
  return idx > 0 ? trimmed.slice(0, idx) : trimmed;
}

function getFileExtension(name) {
  const trimmed = safeTrim(name).toLowerCase();
  const idx = trimmed.lastIndexOf('.');
  if (idx < 0 || idx === trimmed.length - 1) {
    return '';
  }
  return trimmed.slice(idx + 1);
}

function getMaxUploadSize(env) {
  const fromEnv = Number(env.MOD_MAX_FILE_SIZE || 0);
  if (Number.isFinite(fromEnv) && fromEnv > 0) {
    return Math.floor(fromEnv);
  }
  return DEFAULT_MAX_FILE_SIZE;
}

function contentTypeByExtension(ext) {
  switch (ext) {
    case 'zip':
      return 'application/zip';
    case 'rar':
      return 'application/vnd.rar';
    case '7z':
      return 'application/x-7z-compressed';
    default:
      return 'application/octet-stream';
  }
}

async function sha256Hex(arrayBuffer) {
  const digest = await crypto.subtle.digest('SHA-256', arrayBuffer);
  const bytes = new Uint8Array(digest);
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function allocateModSlug(env, rawCandidate) {
  const base = slugify(rawCandidate);
  let candidate = base;
  let seq = 2;

  while (seq < 10_000) {
    const existing = await env.DB.prepare('SELECT id FROM mods WHERE mod_slug = ? LIMIT 1').bind(candidate).first();
    if (!existing) {
      return candidate;
    }

    candidate = `${base}-${seq}`;
    seq += 1;
  }

  throw new Error('Failed to allocate unique mod slug');
}

function slugify(raw) {
  const safe = String(raw || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
  return safe || 'mod';
}

function safeFileToken(raw) {
  const safe = String(raw || '')
    .trim()
    .replace(/[^a-zA-Z0-9._-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
  return safe || '1.0.0';
}

function buildObjectKey(userId, modSlug, version, ext) {
  const timestamp = Date.now();
  const safeVersion = safeFileToken(version);
  return `mods/user_${userId}/${modSlug}-v${safeVersion}-${timestamp}.${ext}`;
}

function clampInt(rawValue, fallback, min, max) {
  if (rawValue === null || rawValue === undefined) {
    return fallback;
  }

  if (typeof rawValue === 'string' && rawValue.trim() === '') {
    return fallback;
  }

  const value = Number(rawValue);
  if (!Number.isFinite(value) || !Number.isInteger(value)) {
    return fallback;
  }

  if (value < min) {
    return min;
  }

  if (value > max) {
    return max;
  }

  return value;
}

function getOrderBy(sort) {
  switch (sort) {
    case 'downloads':
      return 'download_count DESC, created_at DESC';
    case 'rating':
      return 'rating_score DESC, rating_count DESC, created_at DESC';
    case 'new':
    default:
      return 'created_at DESC';
  }
}

async function ensureModsSchema(env) {
  try {
    const table = await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='mods'"
    ).first();

    if (!table) {
      return errorResponse(
        'Mods schema is missing. Run: wrangler d1 execute witch-weapon-users --remote --file=shared/mods-schema.sql',
        500,
        'MOD_SCHEMA_MISSING'
      );
    }

    return null;
  } catch (error) {
    return errorResponse(`Database check failed: ${error.message}`, 500);
  }
}

async function insertModVersionIfAvailable(env, versionData) {
  if (!versionData.modId) {
    return;
  }

  try {
    await env.DB.prepare(
      `INSERT INTO mod_versions (
        mod_id,
        version,
        file_path,
        file_size,
        file_hash,
        changelog
      ) VALUES (?, ?, ?, ?, ?, ?)`
    ).bind(
      versionData.modId,
      versionData.version,
      versionData.filePath,
      versionData.fileSize,
      versionData.fileHash,
      versionData.changelog
    ).run();
  } catch (error) {
    if (!String(error.message || '').includes('no such table')) {
      throw error;
    }
  }
}

async function insertDownloadLogIfAvailable(env, request, modId) {
  try {
    const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
    const userAgent = request.headers.get('User-Agent') || '';

    await env.DB.prepare(
      `INSERT INTO mod_downloads (mod_id, user_id, ip_address, user_agent)
       VALUES (?, NULL, ?, ?)`
    ).bind(modId, ip, userAgent).run();
  } catch (error) {
    if (!String(error.message || '').includes('no such table')) {
      throw error;
    }
  }
}

function parseZipEntries(arrayBuffer) {
  const view = new DataView(arrayBuffer);
  const eocdOffset = findEocdOffset(view);
  if (eocdOffset < 0) {
    throw new Error('Invalid ZIP: end of central directory not found');
  }

  const totalEntries = view.getUint16(eocdOffset + 10, true);
  const centralDirOffset = view.getUint32(eocdOffset + 16, true);
  const entries = [];
  const decoder = new TextDecoder();

  let cursor = centralDirOffset;
  for (let i = 0; i < totalEntries; i += 1) {
    if (cursor + 46 > view.byteLength) {
      throw new Error('Invalid ZIP central directory');
    }

    const signature = view.getUint32(cursor, true);
    if (signature !== 0x02014b50) {
      throw new Error('Invalid ZIP entry header');
    }

    const compression = view.getUint16(cursor + 10, true);
    const compressedSize = view.getUint32(cursor + 20, true);
    const fileNameLength = view.getUint16(cursor + 28, true);
    const extraLength = view.getUint16(cursor + 30, true);
    const commentLength = view.getUint16(cursor + 32, true);
    const localHeaderOffset = view.getUint32(cursor + 42, true);

    const nameStart = cursor + 46;
    const nameEnd = nameStart + fileNameLength;
    if (nameEnd > view.byteLength) {
      throw new Error('Invalid ZIP entry name range');
    }

    const fileName = decoder
      .decode(new Uint8Array(arrayBuffer.slice(nameStart, nameEnd)))
      .replace(/\\/g, '/');

    entries.push({
      fileName,
      compression,
      compressedSize,
      localHeaderOffset,
    });

    cursor += 46 + fileNameLength + extraLength + commentLength;
  }

  return entries;
}

function findEocdOffset(view) {
  const minOffset = Math.max(0, view.byteLength - 65557);
  for (let i = view.byteLength - 22; i >= minOffset; i -= 1) {
    if (view.getUint32(i, true) === 0x06054b50) {
      return i;
    }
  }
  return -1;
}

async function readZipEntryBytes(arrayBuffer, entry) {
  const view = new DataView(arrayBuffer);

  if (entry.localHeaderOffset + 30 > view.byteLength) {
    throw new Error('Invalid ZIP local header range');
  }

  const localSignature = view.getUint32(entry.localHeaderOffset, true);
  if (localSignature !== 0x04034b50) {
    throw new Error('Invalid ZIP local header');
  }

  const nameLength = view.getUint16(entry.localHeaderOffset + 26, true);
  const extraLength = view.getUint16(entry.localHeaderOffset + 28, true);
  const dataStart = entry.localHeaderOffset + 30 + nameLength + extraLength;
  const dataEnd = dataStart + entry.compressedSize;

  if (dataEnd > view.byteLength) {
    throw new Error('Invalid ZIP data range');
  }

  const compressed = new Uint8Array(arrayBuffer.slice(dataStart, dataEnd));

  if (entry.compression === 0) {
    return compressed;
  }

  if (entry.compression === 8) {
    const stream = new Blob([compressed]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
    const decompressed = await new Response(stream).arrayBuffer();
    return new Uint8Array(decompressed);
  }

  throw new Error(`Unsupported ZIP compression method: ${entry.compression}`);
}

function isModConfigPath(fileName) {
  const normalized = fileName.replace(/\\/g, '/').toLowerCase();
  return normalized === 'mod_config.json' || normalized.endsWith('/mod_config.json');
}

function hasZipPath(entries, expectedPath) {
  const expected = String(expectedPath || '')
    .replace(/\\/g, '/')
    .replace(/^\.\//, '')
    .replace(/^\//, '')
    .toLowerCase();

  if (!expected) {
    return false;
  }

  return entries.some((entry) => {
    const normalized = entry.fileName
      .replace(/\\/g, '/')
      .replace(/^\.\//, '')
      .replace(/^\//, '')
      .toLowerCase();

    return normalized === expected || normalized.endsWith(`/${expected}`);
  });
}
