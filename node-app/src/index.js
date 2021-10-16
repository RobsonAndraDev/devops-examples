const app = require('express')()

app.get('/', (req, res) => {
  return res.send({ ping: 'pong'})
})

app.listen(3000, () => {
  console.log('magic happens on 3000')
})
