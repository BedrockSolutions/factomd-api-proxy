console.log('beginning load of testing lib');

statusIs = code =>
  pm.test(`Status code is ${code}`, () => pm.response.to.have.status(code));

ok = () => statusIs(200);

badRequest = () => statusIs(400);

forbidden = () => statusIs(403);

notFound = () => statusIs(404);

serviceUnavailable = () => statusIs(503);

console.log('finished load of testing lib');