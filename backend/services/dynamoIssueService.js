// Lab 7 Model: issues stored in the DynamoDB table named by DYNAMODB_TABLE.
// Same three functions as jsonIssueService.js, so the controller does not change.
//   JSON file                        DynamoDB
//   read the whole file          ->  Scan   (read all items)
//   push + rewrite the file      ->  Put    (add one item)
//   find + change + rewrite      ->  Update (change one item)
const { randomUUID } = require('crypto');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient, ScanCommand, PutCommand, UpdateCommand
} = require('@aws-sdk/lib-dynamodb');

const TABLE = process.env.DYNAMODB_TABLE;

// No keys in the code: on Lambda the IAM role gives permission;
// on your PC the "floci" AWS profile does.
const db = DynamoDBDocumentClient.from(new DynamoDBClient({}));

async function readIssues() {
  const result = await db.send(new ScanCommand({ TableName: TABLE }));
  return result.Items;
}

async function createIssue({ title, description, priority }) {
  const issue = {
    id: randomUUID(),                      // the server creates the id
    title: title.trim(),
    description: description.trim(),
    priority,
    status: 'Open',                        // the server sets the default
    createdAt: new Date().toISOString()    // the server sets the time
  };
  await db.send(new PutCommand({ TableName: TABLE, Item: issue }));
  return issue;
}

async function updateIssueStatus(id, status) {
  try {
    const result = await db.send(new UpdateCommand({
      TableName: TABLE,
      Key: { id },
      UpdateExpression: 'SET #s = :s',              // change the status...
      ConditionExpression: 'attribute_exists(id)',  // ...only if it exists
      ExpressionAttributeNames: { '#s': 'status' }, // "status" is reserved
      ExpressionAttributeValues: { ':s': status },
      ReturnValues: 'ALL_NEW'                       // return updated issue
    }));
    return result.Attributes;
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      return null;                // not found: the controller answers 404
    }
    throw error;
  }
}

module.exports = { readIssues, createIssue, updateIssueStatus };
