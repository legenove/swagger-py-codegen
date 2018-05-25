# -*- coding: utf-8 -*-
from __future__ import absolute_import, print_function

from . import RequestView
from .. import schemas


class {{ name }}(RequestView):

    {%- for method, ins in methods.items() %}

    def {{ method.lower() }}(self, request{{ params.__len__() and ', ' or '' }}{{ params | join(', ') }}, *args, **kwargs):
        {%- for request in ins.requests %}
        print(request.{{ request }})
        {%- endfor %}

        {% if 'response' in  ins -%}
        return {{ ins.response.0 }}, {{ ins.response.1 }}, {{ ins.response.2 }}
        {%- else %}
        pass
        {%- endif %}
    {%- endfor -%}

