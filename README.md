This package contains tools for helping you write [transforms](https://github.com/substack/node-browserify#btransformtr) for [browserify](https://github.com/substack/node-browserify).

Many different transforms perform certain basic functionality, such as turning the contents of a stream into a string, or loading configuration from package.json.  This package contains helper methods to perform these common tasks, so you don't have to write them over and over again.

Installation
============

Install with `npm install --save-dev browserify-transform-tools`.

Loading Configuration
=====================

Suppose you are writing a transform, and you want to load some configuration.  In your index.js:

```JavaScript
var transformTools = require('browserify-transform-tools');

module.exports = funtion(file) {
    config = transformTools.loadTransformConfigSync 'myTransform', file
    ...
}
```

`loadTransformConfigSync()` will search the parent directory of `file` and its ancestors to find a `package.json` file.  Once it finds one, it will look for a key called 'myTransform'.  If this key is for a JSON object, then `loadTransformConfigSync()` will return the object.  If this key is for a string, then `loadTransformConfigSync()` will try to load the JSON or JS file the string represents and will return that instead.  For example, if package.json contains `{"myTransform": "./myTransform.json"}`, then the contents of "myTransform.json" will be returned.

There is an async version of this function, as well.

Creating a String Transform
===========================
Browserify transforms work on streams.  This is all well and good, until you want to call a library like "falafel" which doesn't work with streams.

Suppose you are writing a transform called "unbluify" which replaces all occurances of "blue" with
a color loaded from a configuration:

```JavaScript
var options = {excludeExtensions: [".json"]};
module.exports = transformTools.makeStringTransform("unbluify", options,
    function (content, transformOptions) {
        var file = transformOptions.file;
        var config = transformOptions.config;

        return content.replace(/blue/g, config.newColor);
    });
```

Parameters:

* `transformFn(contents, {file, config})` - Function which is called to do the transform. `contents` are the contents of the file.  `file` is the name of the file (as would be passed to a normal browserify transform.)  `config` is the configuration for the `redify` transform (see `loadTransformConfig` below for details on where this comes from.)

* `options.excludeExtensions` - A list of extensions which will not be processed.  e.g. "['.coffee', '.jade']"

* `options.includeExtensions` - A list of extensions to process.  If this options is not specified, then all extensions will be processed.  If this option is specified, then any file with an extension not in this list will skipped.

Creating a Falafel Transform
============================
Many transforms are based on [falafel](https://github.com/substack/node-falafel). browserify-transform-tools provides an easy way to define such transforms.  Here is an example which wraps all array expressions in a call to `fn()`:

```JavaScript
var options = {};
module.exports = transformTools.makeFalafelTransform("array-fnify", options,
    function (node, transformOptions) {
        if (node.type === 'ArrayExpression') {
            node.update('fn(' + node.source() + ')');
        }
    });
```

Options passed to `makeFalafelTransform()` are the same as for `makeStringTransform()`, as are the options passed to the transform function.
