---
title: Sokol and Odin on iOS
---

First create a new project in xcode. Select the iOS game template, and then set the language as Objective-C and Metal.

![](/images/odin-sokol-ios-1.png)

When you run this project from xcode on an iphone simulator you should see a spinning cube.

![](/images/odin-sokol-ios-2.png)

Next compile your odin project for iOS. We are going to build our code as object files, and then add them to the linking process within odin. There are two targets you can use, iphone and iphonesimulator. You need to make sure you compile for the target you are going to test on as they are not interchangeable.

```
odin build src -target:darwin_arm64 -build-mode:obj -subtarget:iphone -out:build
```
or
```
odin build src -target:darwin_arm64 -build-mode:obj -subtarget:iphonesimulator -out:build
```

this should generate a bunch of `.o` files in the build directory which we need to link with our xcode project. In xcode click on your project in the lefthand sidebar, select Build Phases then expand "Link Binary With Libraries", then from finder click and drag all the generated object files over.

![](/images/odin-sokol-ios-3.png)

We have linked our odin code with our project now, but this doesn't include the actual implementation of sokol. To add sokol we need to find the sokol header files we want, in my case app, gfx, log, glue, and audio, and copy them somewhere in the xcode project. We then want to update the main.m file to import them and define headers telling sokol to build for metal.

Your main.m should look something like

```
#define SOKOL_IMPL
#define SOKOL_METAL
#define SOKOL_NO_ENTRY


#import "sokol_app.h"
#import "sokol_gfx.h"
#import "sokol_log.h"
#import "sokol_glue.h"
#import "sokol_audio.h"

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
```

And that's it, launch your game in the simulator and you should see it boot up
