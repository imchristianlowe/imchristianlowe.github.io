---
title: Planning a Software Project
date: 2022-11-04 00:00:00 +/-TTTT
categories: [Project Management, Software Engineering]
tags: []     # TAG names should always be lowercase
mermaid: true
---

You have an idea for something you want to create but you don't know how to start? Well hopefully this will serve as a starting point. I don't always follow all of these steps, but it would be good if I did then I wouldn't have to redo so much code later on.

What does the general process for a software project look like?


# Tasks with Stakeholders

1. Define the outcome
1. Define requirements

Stakeholders are `the people or groups affected by a software development project`. These tasks are important because they can help catch problems before development work starts and makes sure the project will have the intended impact when you are done with it.

If the project has more than one definite desired outcome or responsibility, it might be too big and need to be broken up into smaller projects.

If the project has too many requirements to be considered done, it either might be too big and need to be broken up or may need to broken down into versions and iterated on over time.

# Tasks without Stakeholders

1. Brainstorming
1. Draw diagrams and document any APIs
    - Data flow
    - Architecture
    - Entity Relationship
    - Unified Modeling Language
1. Define how to deploy changes
1. Define monitoring and alerting
1. Break down work into specific tasks and input into some sort of tracker
1. Get to work
1. Maintain
1. $$

Good documentation is crucial to the longevity of a software project so spend time setting this up in the beginning so the project is more easily debugged and iterated on in the future. Here are some tools that might be helpful.

## Tools for Diagramming

There are many choices out there, but [Draw.io](https://draw.io), [Mermaid.js](https://mermaid-js.github.io/mermaid/#/) and [Mingrammer](https://diagrams.mingrammer.com/) are great and just about all the tools needed to diagram any software project.


### Draw.io
Draw.io is the typical drag and drop flowchart maker with different templates and icons to use. If additional icons or images are needed, there's an option to import pictures from the computer, a URL or GDrive. This is the best one to start with for beginners. 

The other two tools have a steep learning curve, but are really powerful for defining architecture and systems and keeping them updated all while minimizing context switching since they are both code based. 

### Mermaid.js
Mermaid.js is a markdown based diagram generator and can create just about any type of diagram in code.

From the Mermaid.js website
> It is a JavaScript based diagramming and charting tool that renders Markdown-inspired text definitions to create and modify diagrams dynamically.

It's a really powerful tool. The below code snippet produces the image directly below it.

```
graph TD;
    A-->B;
    A-->C;
    B-->D;
    C-->D;
```

```mermaid
graph TD;
    A-->B;
    A-->C;
    B-->D;
    C-->D;
```

### Mingrammer
Mingrammer is a Python based architecture diagramming tool. Taken directly from the Mingrammer Guide, the following Python code generates the image directly below it.
```python
# diagram.py
from diagrams import Diagram
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.network import ELB

with Diagram("Web Service", show=False):
    ELB("lb") >> EC2("web") >> RDS("userdb")
```
![Desktop View](/assets/images/web_service.png){: width="466" height="300" }
_Example image created with Mingrammer_

## Deploying Changes
Whether it's an individual developer or an entire team working on a project, having a pipeline helps reduce human error and gives the developement team more time to focus on writing higher quality code and maintaining their sanity. If you're on a team or an organization, there might already be a pipeline in place. In which case you should use that. If it's an individual developer, just use whatever is easiest, so in my case I'll use Github Actions until I find a use case that can't be solved and I'm forced to search for another solution.

## Breaking Down Work
Having a tool to track goals, milestones, tasks, issues, etc is necessary in order to make sure the project is progressing towards a certain goal and having the greatest impact by implementing the most desired features and resolving issues quickly. While these metrics don't give a full picture of the impact of work, they give some proof of value and progress.

Similar to deciding how to deploy changes, if you're on a larger team or in an org, there might already be in place so just use that. If you're an individual developer, use whatever built in tooling the code hosting provider you're choosing provides. In my case, I use Github so I would use Github Issues until I find a reason not to.

## Get to Work
At this point, the project is well defined and scoped and it's time to start writing the code with confidence that what you're building will be something that people love to use.

## Maintain
Once the code has been written, deployed and users are interacting with it, that's when it goes into monitoring and maintenance mode. There's a lot that goes into monitoring and maintaining an application and that's outside the scope of this guide.

# References
[FreeCodeCamp - Follow These Steps to Start a Successful Software Development Project](https://www.freecodecamp.org/news/follow-these-key-steps-to-start-a-successful-software-development-project-163c838e8fe1/) \
[5280software - 7 Steps to Start a Successful Software Development Project](https://www.5280software.net/blog-post/7-steps-to-start-a-successful-software-development-project/) \
[PlainEnglish - Things to do before Starting a Software Project](https://javascript.plainenglish.io/things-to-do-before-starting-a-software-project-aafc93e7157b?gi=2184f51e2b07/)
