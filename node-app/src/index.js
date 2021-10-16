const app = require('express')()
const mathService = require('./math-service')

app.get('/', (req, res) => {
  return res.send({ ping: 'pong'})
})

app.get('/square/:number', (req, res) => {
  const { number } = req.params

  return res.send({ result: mathService.square(number) })
})

app.listen(3000, () => {
  console.log('magic happens on 3000')
})
