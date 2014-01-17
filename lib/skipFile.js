// Generated by CoffeeScript 1.6.3
(function() {
  var JS_EXTENSIONS, endsWith, isArray, path;

  path = require('path');

  JS_EXTENSIONS = [".js", ".coffee", ".coffee.md", ".litcoffee", "._js", "._coffee"];

  isArray = function(obj) {
    return Object.prototype.toString.call(obj) === '[object Array]';
  };

  endsWith = function(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
  };

  module.exports = function(file, configData, options) {
    var appliesTo, extension, fileToTest, includeExtensions, includeThisFile, regex, regexes, skip, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1;
    if (configData == null) {
      configData = {};
    }
    if (options == null) {
      options = {};
    }
    file = path.resolve(file);
    skip = false;
    appliesTo = configData.appliesTo;
    if ((appliesTo == null) || ((appliesTo.includeExtensions == null) && (appliesTo.excludeExtensions == null) && (appliesTo.regex == null) && (appliesTo.files == null))) {
      appliesTo = options;
    }
    includeExtensions = appliesTo != null ? appliesTo.includeExtensions : void 0;
    if ((appliesTo != null ? appliesTo.jsFilesOnly : void 0) && !includeExtensions) {
      includeExtensions = JS_EXTENSIONS;
    }
    if (appliesTo.regex != null) {
      regexes = appliesTo.regex;
      includeThisFile = false;
      if (!isArray(regexes)) {
        regexes = [regexes];
      }
      for (_i = 0, _len = regexes.length; _i < _len; _i++) {
        regex = regexes[_i];
        if (!regex.test) {
          regex = new RegExp(regex);
        }
        if (regex.test(file)) {
          includeThisFile = true;
          break;
        }
      }
      if (!includeThisFile) {
        skip = true;
      }
    } else if (appliesTo.files != null) {
      includeThisFile = false;
      _ref = appliesTo.files;
      for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
        fileToTest = _ref[_j];
        fileToTest = path.resolve(configData.configDir, fileToTest);
        if (fileToTest === file) {
          includeThisFile = true;
          break;
        }
      }
      if (!includeThisFile) {
        skip = true;
      }
    } else if (appliesTo.excludeExtensions != null) {
      _ref1 = appliesTo.excludeExtensions;
      for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
        extension = _ref1[_k];
        if (endsWith(file, extension)) {
          skip = true;
          break;
        }
      }
    } else if (includeExtensions != null) {
      includeThisFile = false;
      for (_l = 0, _len3 = includeExtensions.length; _l < _len3; _l++) {
        extension = includeExtensions[_l];
        if (endsWith(file, extension)) {
          includeThisFile = true;
          break;
        }
      }
      if (!includeThisFile) {
        skip = true;
      }
    }
    return skip;
  };

}).call(this);