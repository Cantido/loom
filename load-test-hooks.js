const crypto = require("crypto")

module.exports = {
  uuid: uuid
}

function uuid(requestParams, context, ee, next) {
  context.vars.uuid = crypto.randomUUID();
  next();
}
