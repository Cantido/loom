---
title: "About"
menu:
  main:
    weight: 1

---

Loom is an event store that speaks the [CloudEvents specification](https://cloudevents.io).

It is currently in development and not ready for use.
Keep an eye on this space for a release announcement.

In short, Loom sequences event-based data and stores it for you.
Sequencing events is important because it gives you a way to order events in a repeatable way.
If you just relied on timestamps to order events, it is possible for clock jitter to alter the history of your data.

Loom leans heavily on the CloudEvents specification as a representation of event data.
This means that it is compatible with any other system that speaks this well-documented standard.
We will cover CloudEvents here, but you can read the [CloudEvents Primer](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/primer.md) for a more thorough introduction to this specification.

## Event sourcing

Loom is purpose-built to be an event store for event-sourced architectures.
Event sourcing is a technique for building services where instead of recording the current state of your data in a database,
you store a list of changes (AKA events), and derive all of your data from there.
When you treat your change history as the first-class source of data,
you are able to derive new insights from your data.

For example, think of a shopping cart on an e-commerce website.
You are shopping, and you add four items to your cart, then you remove one.
In the traditional architecture, there would be a database somewhere, saying you have three items in your cart.
With an event-sourced architecture, there are four "add item to cart" events in the event history, and one "remove item from cart" event.
A downstream database may say you have three items in your cart at the moment, but you still have record that a fourth item was in there.
Storing a change history means you don't lose data.

What if, tomorrow, someone at the e-commerce website decides to start featuring items that users previously had in their cart, but didn't buy?
Once the traditionally-architected web application was updated, it would only have the data that was created starting at that moment.
An event-sourced system would be updated, and would then re-read the event history, building a new updated picture based on the entire history of your data.
This may take a weekend, if you have a lot of data, but it could be done.
You haven't lost the data.

## CloudEvents

The CloudEvents specification describes itself as "a specification for describing event data in a common way."
It is organized via the Cloud Native Computing Foundation (CNCF)'s Serverless Working Group,
and is one of the CNCF's "incubating" projects.

With the minimum required amount of information, an event in the CloudEvent JSON format looks like this:

```json
{
  "specversion": "1.0",
  "type": "coolevent",
  "id": "xxxx-xxxx-xxxx",
  "source": "bigco.com"
}
```

You can attach a lot of metadata to an event, including a block of arbitrary data.
Data can be anything from a pure binary, structured JSON, or any string.
That means that it can fit data in any encoding or schema.

```json
{
    "specversion" : "1.0",
    "type" : "com.example.someevent",
    "source" : "/mycontext",
    "subject": null,
    "id" : "C234-1234-1234",
    "time" : "2018-04-05T17:31:00Z",
    "comexampleextension1" : "value",
    "comexampleothervalue" : 5,
    "datacontenttype" : "application/json",
    "data" : {
        "appinfoA" : "abc",
        "appinfoB" : 123,
        "appinfoC" : true
    }
}
```
