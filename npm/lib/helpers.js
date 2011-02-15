(function() {
  var async, exec, fileUtil, filterForJsFiles, fs, path, walkTree;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  fs = require('fs');
  path = require('path');
  exec = require('child_process').exec;
  async = require('async');
  fileUtil = require('file');
  exports.copy = function(source, target) {
    return exec('cp -R ' + source + ' ' + target, function(error, stdout, stderr) {
      if (stdout) {
        console.log(stdout);
      }
      if (stderr) {
        console.log(stderr);
      }
      if (error) {
        return console.log(error);
      }
    });
  };
  walkTree = function(directory, callback) {
    return fs.readdir(directory, __bind(function(err, files) {
      if (err) {
        return callback(err);
      }
      return async.forEach(files, __bind(function(file, next) {
        var filename;
        if (file.match(/^\./)) {
          return next();
        }
        filename = path.join(directory, file);
        return fs.stat(filename, __bind(function(err, stats) {
          if (!err && stats.isDirectory()) {
            return walkTree(filename, function(err, filename) {
              if (filename) {
                return callback(err, filename);
              } else {
                return next();
              }
            });
          } else {
            callback(err, filename);
            return next();
          }
        }, this));
      }, this), callback);
    }, this));
  };
  filterForJsFiles = function(files) {
    var file, jsFiles, _i, _len;
    jsFiles = [];
    for (_i = 0, _len = files.length; _i < _len; _i++) {
      file = files[_i];
      if (path.extname(file) === ".js") {
        jsFiles.push(file);
      }
    }
    return jsFiles;
  };
  exports.getFilesInTree = function(directory, callback) {
    var files;
    files = [];
    return walkTree(directory, function(err, filename) {
      if (err) {
        return callback(err);
      } else if (filename) {
        return files.push(filename);
      } else {
        files = filterForJsFiles(files);
        return callback(err, files.sort());
      }
    });
  };
  exports.mkdirsForFile = function(file, mode) {
    var newPath;
    newPath = file.replace(/\/[^\/]*$/, '');
    return fileUtil.mkdirsSync(newPath, mode);
  };
}).call(this);
