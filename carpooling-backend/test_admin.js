const jwt = require('jsonwebtoken');
const token = jwt.sign({ id: '7cfd05d4-5df0-4a3f-9eb4-ab1a8070081b' }, 'vroom_squad_jwt_secret_change_in_prod');
console.log(token);
