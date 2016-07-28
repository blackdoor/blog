---
layout: about
---

This blog is developed and written by the backenders, a bunch of wankers from the USA.

<ul>
{% for member in site.data.backenders %}
  <li>
    <h1>{{ member.name }}</h1>
    <p>{{ member.bio }}</p>
    {% for weblink in member.websites %}
    	<a href="{{ weblink.url }}">{{ weblink.name }}</a>
    {% endfor %}
  </li>
{% endfor %}
</ul>