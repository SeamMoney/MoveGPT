import { OpenAI } from 'langchain/llms';
import { LLMChain, PromptTemplate } from 'langchain';
import { HNSWLib } from "langchain/vectorstores";
import { OpenAIEmbeddings } from 'langchain/embeddings';
import promptTemplate from './basePrompt.js'
import resourcePrompt from './userPrompt.js'
import {getResources,multipleAddrs,getAccount} from './useAccount.js'
const TEST_ADDRESS = "0xba78c665ccef66de6e6ca1fd085a9a2e3e08ef65998df3f419a555e8039f3987"

// Load the Vector Store from the `vectorStore` directory
const store = await HNSWLib.load("docStore", new OpenAIEmbeddings({
  openAIApiKey: process.env.OPENAI_A1PI_KEY
}));
console.clear();

// OpenAI Configuration
const model = new OpenAI({ 
  temperature: 0,
  openAIApiKey: process.env.OPENAI_API_KEY,
  modelName: 'text-davinci-003'
});

// Parse and initialize the Prompt
const prompt = new PromptTemplate({
  template: promptTemplate,
  inputVariables: ["history", "context", "prompt"]
});

// Parse and initialize the  that will find the resources in the account
const resPrompt = new PromptTemplate({
  template: resourcePrompt,
  inputVariables: ["history", "context", "prompt"]
});

// Create the LLM Chain
const llmChain = new LLMChain({
  llm: model,
  prompt
});

const chain2 = new LLMChain({
  llm: model,
  prompt: resPrompt
});

/** 
 * Generates a Response based on history and a prompt.
 * @param {string} history - 
 * @param {string} prompt - Th
 */
const generateResponse = async ({
  history,
  prompt
}) => {
  // Search for related context/documents in the vectorStore directory
  const data = await store.similaritySearch(prompt, 1);
  const context = [];
  data.forEach((item, i) => {
    context.push(`Context:\n${item.pageContent}`)
  });
  
  return await llmChain.predict({
    prompt,
    context: context.join('\n\n'),
    history
  })
}

export default generateResponse;



export const generateResourceResponse = async ({
  history,
  prompt,
  context
}) => {

  
  
  return await chain2.predict({
    prompt,
    context: context,
    history
  })
    
    
   
}

