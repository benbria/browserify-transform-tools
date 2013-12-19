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

module.exports = function(file) {
    var config = transformTools.loadTransformConfigSync('myTransform', file);
    ...
};
```

`loadTransformConfigSync()` will search the parent directory of `file` and its ancestors to find a `package.json` file.  Once it finds one, it will look for a key called 'myTransform'.  If this key is for a JSON object, then `loadTransformConfigSync()` will return the object.  If this key is for a string, then `loadTransformConfigSync()` will try to load the JSON or JS file the string represents and will return that instead.  For example, if package.json contains `{"myTransform": "./myTransform.json"}`, then the contents of "myTransform.json" will be returned.

There is an async version of this function, as well, called `loadTransformConfig()`.

Creating a String Transform
===========================
Browserify transforms work on streams.  This is all well and good, until you want to call a library like "falafel" which doesn't work with streams.

Suppose you are writing a transform called "unbluify" which replaces all occurances of "blue" with a color loaded from a configuration:

```JavaScript
var options = {excludeExtensions: [".json"]};
module.exports = transformTools.makeStringTransform("unbluify", options,
    function (content, transformOptions, done) {
        var file = transformOptions.file;
        var config = transformOptions.config;

        done null, content.replace(/blue/g, config.newColor);
    });
```

Parameters:

* `transformFn(contents, transformOptions, done)` - Function which is called to
  do the transform.  `contents` are the contents of the file.  `transformOptions.file` is the
  name of the file (as would be passed to a normal browserify transform.)
  `transformOptions.config` is the configuration for the transform (see
  `loadTransformConfig` above for details on where this comes from.)  `done(err, transformed)` is
  a callback which must be called, passing the a string with the transformed contents of the
  file.

* `options.excludeExtensions` - A list of extensions which will not be processed.  e.g.
  "['.coffee', '.jade']"

* `options.includeExtensions` - A list of extensions to process.  If this options is not
  specified, then all extensions will be processed.  If this option is specified, then
  any file with an extension not in this list will skipped.

Creating a Falafel Transform
============================
Many transforms are based on [falafel](https://github.com/substack/node-falafel). browserify-transform-tools provides an easy way to define such transforms.  Here is an example which wraps all array expressions in a call to `fn()`:

```JavaScript
var options = {};
// Wraps all array expressions in a call to fn().  e.g. '[1,2,3]' becomes 'fn([1,2,3])'.
module.exports = transformTools.makeFalafelTransform("array-fnify", options,
    function (node, transformOptions, done) {
        if (node.type === 'ArrayExpression') {
            node.update('fn(' + node.source() + ')');
        }
        done();
    });
```

Options passed to `makeFalafelTransform()` are the same as for `makeStringTransform()`, as are the options passed to the transform function.  You can additionally pass a `options.falafelOptions` to `makeFalafelTransform` - this object will be passed as an options object directly to falafel.

Running a Transform
===================
If you want to unit test your transform, then `runTransform()` is for you:

```JavaScript
var myTransform = transformTools.makeFalafelTransform(...);
var dummyJsFile = path.resolve(__dirname, "../testFixtures/testWithConfig/dummy.js");
var content = "console.log('Hello World!');";
transformTools.runTransform(myTransform, dummyJsFile, {content: content},
    function(err, transformed) {
        // Verify transformed is what we expect...
    }
);
```
