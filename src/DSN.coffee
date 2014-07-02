fs              = require 'fs'
ObjUtils        = require 'obj-utils'
DSNOptions      = require './DSNOptions'
{EventEmitter}  = require 'events'
#### DSN
# > Establshes Mongo DB with Mongoose
class DSN extends EventEmitter
  __dsn:null
  constructor:(dsn)->
    @setDSN (if dsn instanceof String then @parseDSNString dsn else dsn) if dsn
  parseDSNString:(string)->
    # this regex is used only to `grep`, so it is expected to match illegal charachters
    if (dsnParams = string.match ///^
      (mongodb\:\/\/)?                           # protocol
      (.+:?.?@)?                                 # username:password@
      ([a-z0-9\.]+)+                             # hostname
      (:[a-zA-Z0-9]{4,5})?                       # :port
      \,?([a-zA-Z0-9\.\,:]*)?                    # replica hosts,
      (\/\w+)?                                   # /database name
      \??([a-zA-Z0-9\_=&\.]*)?                   # options string
      $///) != null       
      return protoDSN = 
        protocol: if dsnParams[1] then dsnParams[1].split(':').shift() else null
        username: if dsnParams[2] then (pass = dsnParams[2].replace('@','').split ':').shift() else null
        password: if pass and pass.length then "#{pass}" else null
        host:     dsnParams[3] || null
        port:     if dsnParams[4] then parseInt dsnParams[4].split(':').pop() else null
        replicas: if dsnParams[5] then dsnParams[5].split(',').map (v,k)-> host:(port=v.split ':').shift(), port:parseInt port.shift() else null
        database: if dsnParams[6] then dsnParams[6].split('/').pop() else null
        options:  if dsnParams[7] then new DSNOptions dsnParams[7] else null
    null
  setOptions:(options)->
    @__dsn ?= {}
    # @__dsn.options = new DSNOptions options
  getOptions:->
    @__dsn?.options || null
  setDSN:(dsn)->
    dsn = @parseDSNString dsn if ObjUtils.isOfType dsn, String
    # dsn.options = new DSNOptions dsn.options if dsn?.options and !ObjUtils.isOfType dsn.options, DSNOptions
    try
      @__dsn = dsn if @validate dsn
    catch e
      throw Error e
  getDSN:->
    @__dsn || null
  validate:(dsn)->
    oTypes =
      protocol:
        type:String
        required:false
        restrict:/^mongodb+$/
      username:
        type:String
        required:false
      password:
        type:String
        required:false
      host:
        type:String
        required:true
        restrict:///^
        (([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])|
        (([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])
        $///
      port:
        type:Number
        required:false
        restrict:/^[0-9]{4,5}$/
      replicas:
        type:Array
        required:false
      database:
        type:String
        required:false
      options:
        type:DSNOptions
        required:false
    for key,value of oTypes
      if dsn[key]?
        # tests for required param type in validator object
        if !value.type
          @emit 'error', "Validator for DSN::'#{key}' was missing type param"
        # tests for proper type
        if !(ObjUtils.isOfType dsn[key], value.type)
          @emit 'error', "#{key} was expected to be #{Util.getFunctionName value.type}. Type was '#{typeof dsn[key]}'"
        # tests for string restriction
        if value.restrict and !("#{dsn[key]}".match value.restrict)
          @emit 'error', "#{key} was malformed"
      # throws error if param was required and not found
      else if value.required
        return @emit 'error', "#{key} was required but not defined"
    if options
      try
        options = new DSNOptions options
      catch e
        @emit 'error', e
    return true
  toJSON:->
    @__dsn
  toDSN:->
    userPass = "#{@__dsn.username || ''}#{if @__dsn.username and @__dsn.password then ':'+@__dsn.password else ''}"
    "#{@__dsn.protocol || 'mongodb'}://#{userPass}#{if userPass.length then '@' else ''}#{@__dsn.host}:#{@__dsn.port || '27017'}/#{@__dsn.database || ''}#{if @__dsn.options then '?'+@__dsn.options else ''}"
  toString:->
    @toDSN()
DSN.loadConfig = (path, callback)->
  try
    data = fs.readFileSync path
  catch e
  try
    config = JSON.parse data
  catch e
  try
    dsn = new DSN if config.hasOwnProperty (env = process.env.NODE_ENV || 'development') then config[env] else config
  catch e
  callback?.apply @, if e? then [e, null] else [null, dsn]
module.exports = DSN