# BitBar ❤️ Haskell

This article explains how to write [BitBar](https://getbitbar.com/) plugins in Haskell. BitBar allows you to put the output of any executable script into MacOS's menu bar. There are a lot of interesting plugins available, but they're mainly written in Bash, Python, Ruby and similar.

I recently learned that you can [script in Haskell](https://www.fpcomplete.com/blog/2016/11/scripting-in-haskell), using [Stack](https://docs.haskellstack.org/en/stable/GUIDE/#script-interpreter), so I took a bit time to write a simple plugin.

## About stack

Stack is a tool for developing Haskell projects. It offers sandboxed development under very stable environment. It is so much more than that, though, so please read on in the [official documentation](https://docs.haskellstack.org/en/stable/README/).

I will just say one more thing: stack was (and still is) a **huge** game changer in Haskell world. I am not a professional Haskell developer, but stack massively improved the overall development experience for me.

## About BitBar

BitBar's mechanism is simple: whatever you write to standard output in your language of choice gets put into the menu bar. BitBar, of course, offers additional customisation options, like text colour, font choice, hrefs etc. Some basic structuring is available, so you can group items as a submenu. The complete API is documented [here](https://github.com/matryer/bitbar#plugin-api).

## About the plugin

At [Seven Bridges](https://www.sevenbridges.com/) we use Jira for our project management. There are some routine things I do everyday in order to follow what's going on with our platform, in terms of serious issues and even minor bugs. Bugs are the main category I'm interested in. Besides that, I want to track deploys that happened recently and just be aware of a release cycle.

So, here's how that relevant info looks like in my menu bar:

![bitbar-haskell-jira.png](resources/C708C32375F2DD59AA9AD90869F9C06B.png =422x46)

That's all one long clickable menu bar item. Clicking it opens the dropdown list with all of the issues that fall under those categories – I will not explain what it means in my case, since the plugin is pretty generic, so I will concentrate on the main concepts, how it works and how to add your own.

This plugin's main concept is a section. Every section is described by a couple of parameters, of which the most important is a [JQL query](https://confluence.atlassian.com/jirasoftwarecloud/advanced-searching-764478330.html#Advancedsearching-ConstructingJQLqueries). In its most simple scenario, this plugin will fetch a list of issues defined by the specified JQL query and then it will do the following:

1. it will create the **main menu bar item**
2. it will create the **section inside the dropdown menu**

Each menu bar item is constructed by joining the icon (in an example above an emoji, but can be any text, really) and a total count for the query executed. Besides specifying the query and an icon to use for display, there are a couple more parameters which control the display of the section:

* **section title**: it is used for dropdown section display. It will appear before the list of issues with current count and total count for a query
* **max results**: this is the maximum number of results to fetch **and** display in the dropdown. Your Jira API limits apply here.
* a **flag** indicating whether to **watch** each issue that was fetched or not (only unwatched items will be watched)
* additional display controls
  * a **flag** controlling the display of a section in the menubar
  * a **flag** controlling the display of a section with 0 issues in the menubar
  * a **flag** controlling the display of a section in the dropdown

### Usage

Like all BitBar plugins, you just need to install it by moving it to your BitBar folder. BitBar also supports the **bitbar://** url scheme, so you can install it by clicking [here](bitbar://openPlugin?title=Jirabar&amp;src=https://raw.githubusercontent.com/msrdic/jirabar/master/jirabar.1m.hs).

After installing, you should set your username and password for authenticating with Jira. Next step is adding a new section descriptor to the list of existing descriptor (one example is included).

## (Maybe) Important

Running this with stack requires that you have all the dependencies already installed.  This particular example depends on some fairly standard libraries ([aeson](https://hackage.haskell.org/package/aeson), [lens-aeson](https://hackage.haskell.org/package/lens-aeson) and [wreq](https://hackage.haskell.org/package/wreq)), but still, if you happen to not have it locally installed, stack will try to fetch and install them. The effects of running this for the first time will depend on your local setup, since it is running stack out of project directory. For more information, I strongly suggest reading the relevant section on scripting with stack mentioned above. What does it mean in practice? First time you start this script, it will take a while if you're starting from scratch with stack.
