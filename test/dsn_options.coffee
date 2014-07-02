fs              = require 'fs'
(chai           = require 'chai').should()
{DSNOptions}    = require '../src'
describe 'DSNOptions Test Suite', ->
  @dsnOpts = new DSNOptions
  it 'should accept new DSNOptions as a String', =>
    @dsnOpts.setOptions "ssl=true&connectTimeoutMS=2000"
    @dsnOpts.getSSL().should.equal true
    @dsnOpts.getConnectTimeoutMS().should.equal 2000
    