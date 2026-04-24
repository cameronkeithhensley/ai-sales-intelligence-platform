// Re-export the shared JWT middleware so call sites inside this service
// read naturally: `require("./middleware/jwt")`.

module.exports = require("../../../shared/node/src/jwt");
