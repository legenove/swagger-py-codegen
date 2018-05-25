# -*- coding: utf-8 -*-

{% include '_do_not_change.tpl' %}
from __future__ import absolute_import

from django.conf.urls import url

{% for view in views -%}
from .views.{{ view.endpoint }} import {{ view.name }}
{% endfor %}

urlpatterns = [
    {%- for view in views %}
    url(r'^{{ view.url }}$', {{ view.name }}.as_view(), kwargs={'endpoint': '{{ view.endpoint }}'}, name=u'{{view.name}}'),
    {%- endfor %}
]