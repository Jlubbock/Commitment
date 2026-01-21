const express = require('express');
const { keccak256, toUtf8Bytes } = require('ethers');
const fs = require('fs');

const app = express();
app.use(express.json());
app.use((_, res, next) => { 
    res.header('Access-Control-Allow-Origin', '*'); 
    res.header('Access-Control-Allow-Headers', '*'); 
    res.header('Access-Control-Allow-Methods', '*');
    next(); 
});
app.options('*', (_, res) => res.sendStatus(200));

const DATA = './messages.json';
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

app.listen(3001, () => console.log('http://localhost:3001'));

