const crypto = require("crypto");
const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

if (!admin.apps.length) {
  admin.initializeApp();
}

const ALLOWED_FOLDERS = new Set(["avatars", "posts", "pins"]);
const CLOUDINARY_CLOUD_NAME = defineSecret("CLOUDINARY_CLOUD_NAME");
const CLOUDINARY_API_KEY = defineSecret("CLOUDINARY_API_KEY");
const CLOUDINARY_API_SECRET = defineSecret("CLOUDINARY_API_SECRET");
const CLOUDINARY_SIGNED_UPLOAD_PRESET = defineSecret(
  "CLOUDINARY_SIGNED_UPLOAD_PRESET"
);

function getBearerToken(authHeader) {
  if (!authHeader || typeof authHeader !== "string") {
    return "";
  }
  const [scheme, token] = authHeader.split(" ");
  if (!scheme || !token || scheme.toLowerCase() !== "bearer") {
    return "";
  }
  return token;
}

function normalizeObjectId(raw) {
  const cleaned = String(raw || "")
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
  if (!cleaned) {
    return "upload";
  }
  return cleaned.slice(0, 80);
}

function buildSignature(paramsToSign, apiSecret) {
  const signatureBase = Object.keys(paramsToSign)
    .sort()
    .map((key) => `${key}=${paramsToSign[key]}`)
    .join("&");

  return crypto
    .createHash("sha1")
    .update(`${signatureBase}${apiSecret}`)
    .digest("hex");
}

exports.cloudinarySignUpload = onRequest(
  {
    cors: true,
    region: "us-central1",
    maxInstances: 10,
    secrets: [
      CLOUDINARY_CLOUD_NAME,
      CLOUDINARY_API_KEY,
      CLOUDINARY_API_SECRET,
      CLOUDINARY_SIGNED_UPLOAD_PRESET,
    ],
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const authToken = getBearerToken(req.headers.authorization);
    if (!authToken) {
      res.status(401).json({ error: "Missing auth token" });
      return;
    }

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(authToken, true);
    } catch (error) {
      res.status(401).json({ error: "Invalid auth token" });
      return;
    }

    const body = req.body && typeof req.body === "object" ? req.body : {};
    const folder = String(body.folder || "").trim().toLowerCase();

    if (!ALLOWED_FOLDERS.has(folder)) {
      res.status(400).json({
        error: "Invalid upload folder. Allowed: avatars, posts, pins",
      });
      return;
    }

    const cloudName = CLOUDINARY_CLOUD_NAME.value() || "";
    const apiKey = CLOUDINARY_API_KEY.value() || "";
    const apiSecret = CLOUDINARY_API_SECRET.value() || "";
    const uploadPreset = CLOUDINARY_SIGNED_UPLOAD_PRESET.value() || "";

    if (!cloudName || !apiKey || !apiSecret || !uploadPreset) {
      res.status(500).json({
        error:
          "Cloudinary signer is not configured. Missing CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET, or CLOUDINARY_SIGNED_UPLOAD_PRESET.",
      });
      return;
    }

    const safeObjectId = normalizeObjectId(body.objectId);
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const publicId = `${decoded.uid}_${safeObjectId}`;
    const signedFolder = `bloomy/${folder}/${decoded.uid}`;
    const context = `app=bloomy|folder=${folder}|owner=${decoded.uid}|object=${safeObjectId}`;
    const tags = `bloomy,app_upload,${folder}`;

    const paramsToSign = {
      context,
      folder: signedFolder,
      overwrite: "false",
      public_id: publicId,
      tags,
      timestamp,
      upload_preset: uploadPreset,
    };

    const signature = buildSignature(paramsToSign, apiSecret);

    res.status(200).json({
      cloud_name: cloudName,
      api_key: apiKey,
      ...paramsToSign,
      signature,
    });
  }
);
