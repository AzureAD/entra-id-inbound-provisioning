const express = require('express');
const multer = require('multer');
const { parseCsv } = require('../services/csvParser');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });

/**
 * POST /api/upload
 * Upload a CSV file, parse it, and return headers + preview rows.
 */
router.post('/', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const { headers, rows } = await parseCsv(req.file.buffer);

    // Store full data in memory for this session (MVP approach)
    req.app.locals.csvData = { headers, rows };

    res.json({
      fileName: req.file.originalname,
      totalRows: rows.length,
      headers,
      preview: rows.slice(0, 5), // First 5 rows for preview
    });
  } catch (err) {
    console.error('CSV parse error:', err);
    res.status(400).json({ error: `Failed to parse CSV: ${err.message}` });
  }
});

/**
 * GET /api/upload/data
 * Get the full uploaded CSV data.
 */
router.get('/data', (req, res) => {
  const csvData = req.app.locals.csvData;
  if (!csvData) {
    return res.status(404).json({ error: 'No CSV data uploaded yet' });
  }
  res.json(csvData);
});

module.exports = router;
