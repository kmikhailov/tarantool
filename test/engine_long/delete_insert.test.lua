test_run = require('test_run')
inspector = test_run.new()
engine = inspector:get_cfg('engine')
iterations = 100000
math.randomseed(1)
delete_insert(engine, iterations)
