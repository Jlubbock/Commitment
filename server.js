const express = require('express');
const path = require('path');
const { keccak256, toUtf8Bytes } = require('ethers');
const fs = require('fs');

const app = express();
app.use(express.json());

// Serve static frontend
app.use(express.static(path.join(__dirname, 'public')));

// Use Railway volume if available, otherwise local file
const DATA = process.env.RAILWAY_VOLUME_MOUNT_PATH 
    ? `${process.env.RAILWAY_VOLUME_MOUNT_PATH}/messages.json`
    : './messages.json';
const load = () => { try { return JSON.parse(fs.readFileSync(DATA)); } catch { return {}; } };
const save = d => fs.writeFileSync(DATA, JSON.stringify(d, null, 2));

app.post('/api/message/:id', (req, res) => {
    const { text, expectedHash } = req.body;
    const hash = keccak256(toUtf8Bytes(text));
    if (hash !== expectedHash) return res.status(400).json({ error: 'hash mismatch' });
    const data = load();
    data[req.params.id] = text;
    save(data);
    res.json({ ok: true });
});

app.get('/api/message/:id', (req, res) => {
    res.json({ text: load()[req.params.id] || null });
});

// Serve frontend for all other routes
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public/ui.html'));
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`http://localhost:${PORT}`));

