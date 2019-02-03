console.log('beginning load of testing lib');

const Ajv = require('ajv');

/*
 * Common functions
 */


/*
 * Status code validation
 */
statusIs = code =>
  pm.test(
    `Status code is ${code}`,
    () => pm.response.to.have.status(code)
  );

ok = () => statusIs(200);

badRequest = () => statusIs(400);

forbidden = () => statusIs(403);

notFound = () => statusIs(404);

serviceUnavailable = () => statusIs(503);


/*
 * Header validation
 */

hasHeader = (header, value) =>
  pm.test(
    value ? `HTTP header "${header}" has value "${value}"` : `HTTP header "${header}" exists`,
    () => pm.response.to.have.header(header, value)
  );


/*
 * JSON value validation
 */

jsonValue = key => _.get(pm.response.json(), key);

jsonKeyExists = key =>
  pm.test(
    `JSON key "${key}" exists`,
    () => pm.expect(jsonValue(key)).to.exist
  );

jsonKeyDoesNotExist = key =>
  pm.test(
    `JSON key "${key}" does not exist`,
    () => pm.expect(jsonValue(key)).not.to.exist
  );

jsonKeyIsOfType = (key, type) =>
  pm.test(
    `JSON key "${key}" of type "${type}"`,
    () => pm.expect(jsonValue(key)).to.be.a(type)
  );

jsonKeyEquals = (key, value) =>
  pm.test(
    `JSON key "${key}" equals "${value}"`,
    () => pm.expect(jsonValue(key)).to.equal(value)
  );

jsonKeyDeepEquals = (key, value) =>
  pm.test(
    `JSON key "${key}" deep equals "${value}"`,
    () => pm.expect(jsonValue(key)).to.deep.equal(value)
  );

jsonKeyIncludes = (key, value) =>
  pm.test(
    `JSON key "${key}" includes "${value}"`,
    () => pm.expect(jsonValue(key)).to.deep.include(value)
  );

jsonKeyConformsTo = ({key, schema, schemaName}) => {
  ajv = new Ajv({logger: console});
  const value = jsonValue(key);
  const isValid = ajv.validate(schema, value);

  pm.test(
    `JSON key "${key}" conforms to "${schemaName}" schema`,
    () => pm.expect(isValid).to.be.true
  );
};


/*
 * JSON RPC validation
 */
const jsonRpcSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    error: {
      type: 'object',
      additionalProperties: false,
      properties: {
        code: {
          type: 'number'
        },
        data: {
          type: 'object',
        },
        message: {
          type: 'string',
        }
      },
      required: [
        'code',
        'message',
      ]
    },
    id: {
      type: ['number', 'string'],
    },
    jsonrpc: {
      const: '2.0',
    },
    result: {
      type: 'object'
    }
  },
  required: [
    'id',
    'jsonrpc',
  ],
  oneOf: [
    {
      required: ['error']
    },
    {
      required: ['result']
    },
  ],
};

jsonRpcIsValid = () =>
  pm.test(`Response is valid JSON RPC`, () => pm.response.to.have.jsonSchema(jsonRpcSchema));


/*
 * Health check validation
 */

const healthCheckSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    data: {
      type: 'object',
      additionalProperties: false,
      properties: {
        clocks: {
          type: 'object',
          additionalProperties: false,
          properties: {
            spread: {
              type: 'number',
              minimum: 0,
            },
            spreadTolerance: {
              type: 'number',
              minimum: 1,
              maximum: 60,
            },
            factomd: {
              type: 'number',
            },
            proxy: {
              type: 'number',
            },
          },
        },
        currentBlock: {
          type: 'object',
          additionalProperties: false,
          properties: {
            age: {
              type: 'number',
              minimum: 0,
              maximum: 1200,
            },
            maxAge: {
              type: 'number',
              minimum: 600,
              maximum: 1800,
            },
            startTime: {
              type: 'number',
            },
          },
        },
        currentMinute: {
          type: 'object',
          additionalProperties: false,
          properties: {
            minute: {
              type: 'number',
              minimum: 0,
              maximum: 9,
            },
            startTime: {
              type: 'number',
            },
            age: {
              type: 'number',
              minimum: 0,
              maximum: 120,
            },
          },
        },
        flags: {
          type: 'object',
          additionalProperties: false,
          properties: {
            isClockSpreadOk: {
              type: 'boolean',
            },
            isFollowingMinutes: {
              type: 'boolean',
            },
            isCurrentBlockAgeValid: {
              type: 'boolean',
            },
            isSynced: {
              type: 'boolean',
            },
          },
        },
        heights: {
          type: 'object',
          additionalProperties: false,
          properties: {
            leader: {
              type: 'number',
            },
            entry: {
              type: 'number',
            },
            entryBlock: {
              type: 'number',
            },
            directoryBlock: {
              type: 'number',
            },
          },
        },
      },
      required: [
        'clocks',
        'currentBlock',
        'currentMinute',
        'flags',
        'heights',
      ],
    },
    isHealthy: {
      type: 'boolean',
    },
    message: {
      type: 'string',
    }
  },
  required: [
    'data',
    'isHealthy',
    'message',
  ],
};

healthCheckConforms = () => jsonKeyConformsTo({key: 'result', schema: healthCheckSchema, schemaName: 'health check'});

healthCheckIsGood = () => {
  healthCheckConforms();

  jsonKeyIncludes('result', {
    isHealthy: true,
  });

  jsonKeyIncludes('result.data.flags', {
    isClockSpreadOk: true,
    isFollowingMinutes: true,
    isCurrentBlockAgeValid: true,
    isSynced: true,
  });
};

console.log('finished load of testing lib');
