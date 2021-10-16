const mathService = require('./math-service')

describe('Test math service', () => {
  test('shuld square 2 to be equal 4', () => {
    const result = mathService.square(2)

    expect(result).toBe(4)
  })
})
