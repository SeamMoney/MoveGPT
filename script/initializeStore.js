// import glob from 'glob';
// import fs from 'fs'
// import { CharacterTextSplitter } from "langchain/text_splitter";
// import { HNSWLib } from "langchain/vectorstores";
// import { OpenAIEmbeddings } from 'langchain/embeddings';


import * as fs from "fs";
import * as yaml from "js-yaml";
import { OpenAI } from "langchain/llms/openai";
import { JsonSpec, JsonObject } from "langchain/tools";
import { createOpenApiAgent, OpenApiToolkit } from "langchain/agents";


let data = [];

const yamlFile = fs.readFileSync("aptos_spec.yaml", "utf8");
data = yaml.load(yamlFile);
if (!data) {
  throw new Error("Failed to load OpenAPI spec");
}

const headers = {
  "Content-Type": "application/json",
  Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
};
const model = new OpenAI({ temperature: 0 });
const toolkit = new OpenApiToolkit(new JsonSpec(data), model, headers);
const executor = createOpenApiAgent(model, toolkit);

const input = `Make a POST request to openai /completions. The prompt should be 'tell me a joke.'`;
console.log(`Executing with input "${input}"...`);

const result = await executor.call({ input });
console.log(`Got output ${result.output}`);

console.log(
  `Got intermediate steps ${JSON.stringify(
    result.intermediateSteps,
    null,
    2
  )}`
);


// const data = [];
// const files = await new Promise((resolve, reject) => 
//   glob("training/**/*.md", (err, files) => err ? reject(err) : resolve(files))
// );

// for (const file of files) {
//   data.push(fs.readFileSync(file, 'utf-8'));
// }

// console.log(`Added ${files.length} files to data.  Splitting text into chunks...`);

// const textSplitter = new CharacterTextSplitter({
//   chunkSize: 2000,
//   separator: "\n"
// });

// let docs = [];
// for (const d of data) {
//   const docOutput = textSplitter.splitText(d);

//   const t = textSplitter.
//   docs = [...docs, ...docOutput];
// }

// console.log("Initializing Store...");

// const store = await HNSWLib.fromTexts(
//   docs,
//   docs.map((_, i) => ({ id: i })),
//   new OpenAIEmbeddings({
//     openAIApiKey: process.env.OPENAI_API_KEY
//   })
// )

// console.clear();
// console.log("Saving Vectorstore");

// store.save("vectorStore")

// console.clear();
// console.log("VectorStore saved");