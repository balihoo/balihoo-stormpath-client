
gulp = require 'gulp'
coffeelint = require 'gulp-coffeelint'
coffee = require 'gulp-coffee'
mocha = require 'gulp-mocha'


src = 'src/*.coffee'



gulp.task 'lint', ->
  gulp.src src
  .pipe coffeelint './test/coffeelint.conf.json'
  .pipe coffeelint.reporter()
  .pipe coffeelint.reporter 'fail'
  
#todo: keep comments
gulp.task 'compile', ['lint'], ->
  gulp.src src
  .pipe coffee()
  .pipe gulp.dest 'lib'
  
gulp.task 'test', ['compile'], ->
  gulp.src 'test/*.*'
  .pipe mocha
    bail:true
    reporter:'spec'
    ui: 'bdd'
  
gulp.task 'default', ['test']