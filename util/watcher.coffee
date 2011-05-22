fs            = require 'fs'
fileUtil      = require 'file'
path          = require 'path'
watchTree     = require 'watch-tree'
child_process = require 'child_process'
_             = require 'underscore'

class Watcher
  constructor: (@options) ->
  
  watch: ->
    @runCompass @options.compass if @options.compass
    @watchTree @options.root, @options.sampleRate if @options.paths
  
  watchTree: (root = '.', sampleRate = 5) -> 
    console.log "Watching for changes under root '#{root}' to paths #{JSON.stringify _.keys @options.paths}"
    watcher = watchTree.watchTree(root, {'sample-rate': sampleRate})
    
    watcher.on('fileModified', @handleFile)
    watcher.on('fileCreated', @handleFile)    
  
  runCompass: (config) ->
    console.log "Starting compass with config file '#{config}'"
    @spawn 'compass', ['watch', '-c',  config]
  
  spawn: (command, args, callback) ->
    child = child_process.spawn command, args
    child.stdout.on 'data', (data) =>
      @log "stdout from '#{command}': #{data}"
    child.stderr.on 'data', (data) =>
      console.log "stderr from '#{command}': #{data}"      
    child.on 'exit', (code) =>
      @log "'#{command}' exited with code #{code}"
      callback code if callback
      
  handleFile: (file, stats) =>     
    match = _.detect @options.paths, (value, key) =>     
      new RegExp(key).test file
    @processFile file, match if match

  processFile: (file, options) ->
    console.log "Processing change at '#{file}'"
    switch options.type
      when 'coffee' then @compileCoffee file, options.out
      when 'template' then @compileTemplate file, options.out
      else console.log "Unrecognized type '#{type}', skipping file '#{file}'"
    @packageFiles file if options.package
    
  compileCoffee: (file, out) ->
    @log "Compiling CoffeeScript file '#{file}' to '#{out}'"
    @spawn 'coffee', ['--output', out, '--compile', file]
    
  compileTemplates: (templateDir, templateExtension, out) ->
    @log "Compiling all templates under '#{templateDir}' to '#{out}'"  

    templates = fs.readdirSync templateDir
    for template in templates
      @compileTemplate path.join(templateDir, template), out if path.extname(template) == templateExtension
    
  compileTemplate: (file, out) ->
    @log "Compiling template file '#{file}' to '#{out}' and adding it to templates object"

    templateName = path.basename(file, path.extname(file));
    compiled = _.template(fs.readFileSync(file, 'UTF-8'));
    @options.templates[templateName] = compiled
    
    asString = compiled.toString().replace('function anonymous', "window.templates || (window.templates = {});\nwindow.templates.#{templateName} = function") + ';';       
    fileUtil.mkdirs out, 0755,  =>      
      fs.writeFileSync(path.join(out, "#{templateName}.js"), asString);
  
  packageFiles: (file) ->
    @log 'Packaging files using jammit'
    @spawn 'jammit', ['-c', @options.package, '-o', @options.packageOut]
  
  log: (message) ->
    console.log message if @options.verbose    
      
exports?.watcher = Watcher