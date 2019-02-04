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

headerEquals = (header, value) =>
  pm.test(
    `HTTP header "${header}" equals value "${value}"`,
    () => pm.response.to.have.header(header, value)
  );

headerExists = header =>
  pm.test(
    `HTTP header "${header}" exists`,
    () => pm.response.to.have.header(header)
  );

headerDoesNotExist = header =>
  pm.test(
    `HTTP header "${header}" does not exist`,
    () => pm.response.to.not.have.header(header)
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
    `JSON key "${key}" includes '${JSON.stringify(value)}'`,
    () => pm.expect(jsonValue(key)).to.deep.include(value)
  );

jsonKeyConformsTo = ({key, schema, schemaName}) => {
  if (key) {
    ajv = new Ajv({logger: console});
    const value = jsonValue(key);
    const isValid = ajv.validate(schema, value);

    pm.test(
      `JSON key "${key}" conforms to "${schemaName}" schema`,
      () => pm.expect(isValid).to.be.true
    );
  } else {
    pm.test(
      `JSON comforms to "${schemaName}" schema`,
      () => pm.response.to.have.jsonSchema(schema)
    );
  }
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

const jsonRpcHasErrorSchema = {
  type: 'object',
  properties: {
    error: {
      type: 'object',
    },
    result: {
      const: null,
    },
  },
  required: ['error'],
};

const jsonRpcHasResultSchema = {
  type: 'object',
  properties: {
    error: {
      const: null,
    },
    result: {
      type: 'object',
    },
  },
  required: ['result'],
};

jsonRpcIsValid = () =>
  pm.test(`Response is valid JSON RPC`, () => pm.response.to.have.jsonSchema(jsonRpcSchema));

jsonRpcHasError = code => {
  pm.test(`Response JSON has error and no result`, () => pm.response.to.have.jsonSchema(jsonRpcHasErrorSchema));
  jsonKeyIncludes('error', {code});
};

jsonRpcHasResult = () =>
  pm.test(`Response JSON has result and no error`, () => pm.response.to.have.jsonSchema(jsonRpcHasResultSchema));


/*
 * Health check validation
 */

const healthCheckSchema = {
  type: 'object',
  properties: {
    result: {
      type: 'object',
      additionalProperties: false,
      properties: {
        data: {
          type: 'object',
          additionalProperties: false,
          properties: {
            isHealthy: {
              type: 'boolean',
            },
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
            'isHealthy',
          ],
        },
        message: {
          type: 'string',
        }
      },
      required: [
        'data',
        'message',
      ],
    }
  },
};

const healthCheckBadFlagsSchema = {
  type: 'object',
  anyOf: [
    {
      properties: {
        isClockSpreadOk: {
          const: false,
        }
      },
    },
    {
      properties: {
        isFollowingMinutes: {
          const: false,
        }
      },
    },
    {
      properties: {
        isCurrentBlockAgeValid: {
          const: false,
        }
      },
    },
    {
      properties: {
        isSynced: {
          const: false,
        }
      },
    },
  ],
};

healthCheckConforms = () => jsonKeyConformsTo({schema: healthCheckSchema, schemaName: 'health check'});

healthCheckIsGood = () => {
  healthCheckConforms();

  jsonKeyIncludes('result.data', {
    isHealthy: true,
  });

  jsonKeyIncludes('result.data.flags', {
    isClockSpreadOk: true,
    isFollowingMinutes: true,
    isCurrentBlockAgeValid: true,
    isSynced: true,
  });
};

healthCheckIsBad = () => {
  healthCheckConforms();

  jsonKeyIncludes('error.data', {
    isHealthy: false,
  });

  jsonKeyConformsTo({key: 'error.data.flags', schema: healthCheckBadFlagsSchema, schemaName: 'one or more bad flags'});
};


/*
 * CORS validation
 */

corsPreflightAllowed = ({method}) => {
  const isWildcard = pm.variables.get('isWildcard') === 'true';
  headerEquals('Access-Control-Allow-Credentials', isWildcard ? 'false' : 'true');
  headerEquals('Access-Control-Allow-Headers', pm.variables.get('accessControlRequestHeaders'));
  headerEquals('Access-Control-Allow-Methods', method);
  headerEquals('Access-Control-Allow-Origin', isWildcard ? '*' : pm.variables.get('origin'));
};

corsPreflightDenied = () => {
  headerDoesNotExist('Access-Control-Allow-Credentials');
  headerDoesNotExist('Access-Control-Allow-Headers');
  headerDoesNotExist('Access-Control-Allow-Methods');
  headerDoesNotExist('Access-Control-Allow-Origin');
};


console.log('finished load of testing lib');
