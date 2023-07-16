import express from 'express';
import generateResponse from './lib/generateResponse.js';
import promptSync from 'prompt-sync';

const app = express();
const port = 3000;

const prompt = promptSync();
const conversationHistory = [];

app.use(express.json());

app.get('/', (req, res) => {
  res.send('MoveGPT API is running');
});

app.post('/generate-response', async (req, res) => {
  const { question } = req.body;
  console.log(`Human: ${question}`);
  const answer = await generateResponse({
    prompt: question,
    history: conversationHistory
  });

  conversationHistory.push(`Human: ${question}`, `MoveGPT: ${answer}`);
  console.log(answer);
  res.json({ answer });
});

app.listen(port, () => {
  console.log(`MoveGPT API is listening at http://localhost:${port}`);
});
