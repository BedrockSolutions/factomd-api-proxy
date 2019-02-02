console.log('beginning load of testing lib');

/*
 * Common functions
 */


/*
 * Status code validation
 */
statusIs = code =>
  pm.test(`Status code is ${code}`, () => pm.response.to.have.status(code));

ok = () => statusIs(200);

badRequest = () => statusIs(400);

forbidden = () => statusIs(403);

notFound = () => statusIs(404);

serviceUnavailable = () => statusIs(503);


/*
 * JSON RPC validation
 */
const jsonRpcSchema = {
  type: 'object',
  properties: {
    id: {
      oneOf: [
        {
          type: 'number',
        },
        {
          type: 'string',
        }
      ],
    }
  },
  required: [
    'id',
    'jsonrpc',
  ],
  oneOf: [
    {
      required: ['result']
    },
    {
      required: ['errror']
    }
  ]
}

validJsonRpc = pm.test(`Response is valid JSON RPC`, () => pm.response.to.have.jsonSchema(jsonRpcSchema));

console.log('finished load of testing lib');
