transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"

describe "transformTools require transforms", ->
    it "should generate a transform for require", (done) ->
        transform = transformTools.makeRequireTransform "requireTransform", (args, opts, cb) ->
            if args[0] is "foo"
                cb null, "require('bar')"
            else
                cb()

        content = """
            require('foo');
            require('baz');
            """
        expectedContent = """
            require('bar');
            require('baz');
            """
        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()

    it "should handle simple expressions", (done) ->
        transform = transformTools.makeRequireTransform "requireTransform", (args, opts, cb) ->
            if args[0] is "foo"
                cb null, "require('bar')"
            else if args[0] is "a/b"
                cb null, "require('qux')"
            else
                cb()

        content = """
            require('fo' + 'o');
            require(path.join('a', 'b'));
            """
        expectedContent = """
            require('bar');
            require('qux');
            """
        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()

    it "should optionally not handle simple expressions", (done) ->
        transform = transformTools.makeRequireTransform "requireTransform",
            {evaluateArguments: false}, (args, opts, cb) ->
                if args[0] is "'foo'"
                    cb null, "require('bar')"
                else
                    cb()

        content = """
            require('foo');
            require(path.join('a', 'b'));
            """
        expectedContent = """
            require('bar');
            require(path.join('a', 'b'));
            """
        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()

    it "should not gak on expression it doesn't understand", (done) ->
        transform = transformTools.makeRequireTransform "requireTransform", (args, opts, cb) ->
            if args[0] is "foo"
                cb null, "require('bar')"
            else
                cb()

        content = """
            require(x + y);
            require('foo');
            """
        expectedContent = """
            require(x + y);
            require('bar');
            """
        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()


    it "should return an error when require transform returns an error", (done) ->
        transform = transformTools.makeRequireTransform "requireTransform", (args, opts, cb) ->
            cb new Error("foo")

        transformTools.runTransform transform, dummyJsFile, {content:"require('boo');"}, (err, result) ->
            assert.equal err?.message, "foo (while processing /Users/jwalton/benbria/browserify-transform-tools/testFixtures/testWithConfig/dummy.js)"
            done()

    it "should return an error when require transform throws an error", (done) ->
        transform = transformTools.makeRequireTransform "requireTransform", (args, opts, cb) ->
            throw new Error("foo")

        transformTools.runTransform transform, dummyJsFile, {content:"require('boo');"}, (err, result) ->
            assert.equal err?.message, "foo (while processing /Users/jwalton/benbria/browserify-transform-tools/testFixtures/testWithConfig/dummy.js)"
            done()
