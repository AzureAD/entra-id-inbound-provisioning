const { parse } = require('csv-parse');

/**
 * Parse a CSV buffer/string and return { headers, rows }.
 * Each row is an object keyed by column header.
 */
function parseCsv(buffer) {
  return new Promise((resolve, reject) => {
    const results = [];
    const parser = parse(buffer, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
      bom: true,
    });

    parser.on('data', (row) => results.push(row));
    parser.on('error', (err) => reject(err));
    parser.on('end', () => {
      const headers = results.length > 0 ? Object.keys(results[0]) : [];
      resolve({ headers, rows: results });
    });
  });
}

module.exports = { parseCsv };
