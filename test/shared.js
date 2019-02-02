console.log('beginning load of testing lib')

const statusIs = code =>
  pm.test(`Status code is ${code}`, () => pm.response.to.have.status(code))

const ok = () => statusIs(200)

const badRequest = () => statusIs(400)

const forbidden = () => statusIs(403)

notFound = () => statusIs(404)

const serviceUnavailable = () => statusIs(503)

const isTestLibLoaded = true

console.log('finished load of testing lib')