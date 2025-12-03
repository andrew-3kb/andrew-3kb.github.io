---
title: Browser Threads In Odin
---

I'm currently making my next game Don't Be No Joker in odin and sokol. One of my goals is to ship it to everywhere I reasonably can: Windows + Mac + Linux + Android + iOS + the web. This includes them all supporting the same features which requires multithreading, and while the web does support multithreading through web workers, I couldn't find examples of people getting working with odin on the web. I eventually got them working so hopefully this explanation of how helps someone out. I also have a minimal example of a codebase with them working [over on github](https://github.com/andrew-3kb/odin-emscripten-pthreads-example) .

When compiling for the web I need to use emscripten to build sokol and link with our odin code. We can build the odin code with the freestanding wasm target or like most people use the JS target which supports a lot of odin packages out of the box that don't work freestanding. The JS target's generated wasm however relies on imports found in a provided `odin.js` file, and some work is needed to pass them along. [Karl Zylinski has a great template for using odin and sokol on the web](https://github.com/karl-zylinski/odin-sokol-hot-reload-template) and he makes this work by bypassing the usual method of loading emscripten wasm and instead loads it manually in the `index.html` so he can manage passing the imports himself. Kyle's method however does not support threads as while he loads the main thread himself with the imports, emscripten manages loading the next threads and doesn't pass them.

### Pthreads In Odin

We can't use odin's bundled threading library directly as it's not supported in the JS target, so we will have to build our own threading scaffolding. Luckily emscripten provides a pthreads implementation, and all we need to do is define the functions in odin.

```
pthread_t :: distinct uintptr

@(default_calling_convention = "c")
foreign _ {
  pthread_create :: proc(thread: ^pthread_t, attr: rawptr, start_routine: proc(arg: rawptr) -> rawptr, arg: rawptr) -> c.int ---
  pthread_join :: proc(thread: pthread_t, retval: ^rawptr) -> c.int ---
}
```

and then we can create a thread using them, including passing data to the thread

```
ThreadData :: struct {
  ctx:  runtime.Context,
}

thread_fn :: proc "c" (arg: rawptr) -> rawptr {
  data := cast(^ThreadData)arg
  context = data.ctx
  log.info("Hello from a pthread!")
  return nil
}

main :: proc () {
  data_ptr := new(ThreadData)
  data_ptr^ = { ctx = context }
  thread_id: pthread_t
  pthread_create(&thread_id, nil, thread_fn, data_ptr)
  log.info("Hello from the main thread!")
  pthread_join(thread_id, nil)
  free(data_ptr)
}
```

To get the above to compile we need to tell emcc we are using pthreads and to make a pool for us with the flags `-sUSE_PTHREADS=1 -sPTHREAD_POOL_SIZE=2`. We will also need to compile our odin code with atomics and bulk memory `-target-features="atomics,bulk-memory"`

Here is the full script I use to compile my program
```
odin build src -target:js_wasm32 -target-features="atomics,bulk-memory" -build-mode:obj -out:game.wasm.o
emcc -o index.html game.wasm.o -sUSE_PTHREADS=1 -sPTHREAD_POOL_SIZE=2 -sERROR_ON_UNDEFINED_SYMBOLS=0  -sWASM_BIGINT -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=5MB --shell-file index_template.html
```

### Odin.js imports

The odin code should be good now, it will call emscripten's implementation of pthreads and that will handle it from there. However we still need to solve the problem of passing the `odin.js` imports to the wasm in the threads. This is made harder as the odin imports are not clone-able, so can't be passed between threads, they will have to be created inside each thread individually.

The emscripten generated `index.js` file is what is ran on every thread's startup, including the main thread. If we move the loading of `odin.js` into there, and update it to pass the imports along when it loads the wasm we should be able to get around the issue.

We are going to add some code to the top of the `index.js` file that will run automatically when the page loads, and also on each thread as it's created

```
// A thread local global variable where the odin imports are stored and accessed from
odinImports = {}

// The created threads won't have access to the browsers global window object
// which odin.js expects to exist - so check if it's missing and if so set it
// to a blank object
window = typeof window === "undefined" ? {} : window

// Import the odin.js which will get auto run. We can then set the odinImports
// object to be real. We assign this promise to waitForOdinImports so we can
// gate anything expecting odinImports to be set behind it
waitForOdinImports = import("/odin.js").then(() => {
  const odin = window.odin
  const odinMemoryInterface = new odin.WasmMemoryInterface();
  odinMemoryInterface.setIntSize(4);
  odinImports = odin.setupDefaultImports(odinMemoryInterface);
});
```

Now we have got the imports in each thread, we need to make sure they are returned from the `getWasmImports` function. We can update it to include the `odinImports` we created before like so:

```
function getWasmImports() {
  assignWasmImports();
  var imports = {
    ...odinImports,
    "env": wasmImports,
    "wasi_snapshot_preview1": wasmImports
  };
  return imports;
}
``` 
We also need to make sure the thread has finished importing `odin.js` by the time `getWasmImports()` gets called, so we need to gate it behind the promise we made. The most convenient place I've found to do this is in the two places where the code looks like 
```
createWasm();
run();
```

We update both to be
```
waitForOdinImports.then(() => {
	createWasm();
	run();
});
```
and that's it. However manually editing the index.js file every time is tedious, so you might want to automate it, see the example repo for a python script that does this.

### CORS and Hosting

Emscripten pthreads use SharedArrayBuffer, a web feature that is only enabled if the server where your code is hosted sends specific headers in it's response. [You can read more about this over on mdn](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer). This means that simply serving the files will result in errors. See the [example code](https://github.com/andrew-3kb/odin-emscripten-pthreads-example/blob/master/build.py) for a small python server that sends the needed headers.

### Safari Issues

Work perfectly in chrome that is, safari however will give memory access errors. I'm not 100% sure why this happens but can be mitigated by giving emcc a total memory size `-sTOTAL_MEMORY=64MB`
