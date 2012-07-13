fs = require 'fs'
inflection = require 'inflection'
sys-path = require 'path'
async = require 'async'
common = require './common'
helpers = require '../helpers'
logger = require '../logger'

# Load and cache static files, used for require_definition.js and test_require_definition.js
_get-static-file = async.memoize (filename, callback) ->
  path = sys-path.join __dirname, '..', '..', 'vendor', filename
  error, result <- fs.read-file path
  if error?
    logger.error error 
  else
    callback null, result.to-string!

# The definition would be added on top of every filewriter .js file.
get-require-definition     = _get-static-file.bind null, 'require_definition.js'
get-test-require-definition = _get-static-file.bind null, 'test_require_definition.js'


# File which is generated by brunch from other files.
module.exports = class Generated-file
  # 
  # path        - path to file that will be generated.
  # source-files - array of `fs_utils.Source-file`-s.
  # config      - parsed application config.
  # 
  (@path, @source-files, @config, minifiers) ->    
    type = @type = if @source-files.some (.type is 'javascript')
      'javascript'
    else
      'stylesheet'
    @minifier = minifiers.filter (.type is type) .0
    @is-tests-file = @type is 'javascript' and /tests\.js$/test @path
    Object.freeze this

  _extract-order: (files, config) ->
    types = files.map (file) -> inflection.pluralize file.type
    Object.keys(config.files)
      |> filter (`elem` types)
      # Extract order value from config.
      |> map (key) ->
        config.files[key]order
      # Join orders together.
      |> fold((memo, array) ->
        array or= {}
        {
          before: memo.before +++ array@@before
          after: memo.after +++ array@@after
          vendor-paths: [config.paths.vendor]
        }
      ) before: [] after: []

  _sort: (files) ->
    paths = files.map (.path)
    indexes = {}
    files.for-each (file, index) -> indexes[file.path] = file
    order = @_extract-order files, @config
    helpers.sort-by-config paths, order .map (indexes.)

  _load-test-files: (files) ->
    files
      |> map (lookup 'path')
      |> filter (path) -> /_test\.[a-z]+$/test path
      |> map (path) ->
        path = path.replace /\\/g, '/'
        path.substring 0 path.last-index-of '.'
      |> map (path) -> "this.require('#path');"
      |> unlines

  # Private: Collect content from a list of files and wrap it with
  # require.js module definition if needed.
  # Returns string.
  _join: (files, callback) ->
    logger.debug "Joining files '#{files.map (.path) .join ', '}'
 to '#{@path}'"
    joined = files.map((file) -> file.cache.data).join('')
    if @type is 'javascript'
      if @is-tests-file
        get-test-require-definition (error, require-definition) ~>
          callback error, require-definition + joined + '\n' + @_load-test-files(files)
      else
        get-require-definition (error, require-definition) ~>
          callback error, require-definition + joined
    else
      process.next-tick ~>
        callback null joined

  # Private: minify data.
  # 
  # data     - string of js / css that will be minified.
  # callback - function that would be executed with (minify-error, data).
  # 
  # Returns nothing.
  _minify: (data, callback) ->
    if @config.minify and @minifier?minify?
      @minifier.minify data, @path, callback
    else
      callback null, data

  # Joins data from source files, minifies it and writes result to 
  # path of current generated file.
  # 
  # callback - minify / write error or data of written file.
  # 
  # Returns nothing.
  write: (callback) ->
    error, joined <~ @_join (@_sort @source-files)
    if error?
      callback error
    else
      error, data <~ @_minify joined
      if error?
        callback error
      else
        common.write-file @path, data, callback