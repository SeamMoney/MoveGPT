import generateResponse from "./lib/generateResponse.js";
import promptSync from 'prompt-sync';

const prompt = promptSync();

const conversationHistory = [];

while (true) {
  const question = prompt("Generate Move Code >");
  const answer = await generateResponse({
    prompt: question,
    history: conversationHistory
  });

  console.log(`MoveGPT: ${answer}\n`);
  
  conversationHistory.push(`Human: ${question}`, `MoveGPT: ${answer}`)
}