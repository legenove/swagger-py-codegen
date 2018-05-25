# -*- coding: utf-8 -*-

{% include '_do_not_change.tpl' %}
from __future__ import absolute_import
from werkzeug.datastructures import MultiDict
from django.utils.datastructures import MultiValueDict

import json
import six
from functools import wraps
from jsonschema import Draft4Validator
from django.http.response import HttpResponse, HttpResponseForbidden

from .schemas import validators, scopes, normalize, filters, security


class ValidatorAdaptor(object):

    def __init__(self, schema):
        self.validator = Draft4Validator(schema)

    def validate_number(self, type_, value):
        try:
            return type_(value)
        except ValueError:
            return value

    def type_convert(self, obj):
        if obj is None or not obj:
            return None
        if six.PY3:
            if isinstance(obj, str):
                obj = MultiDict(json.loads(obj))
        else:
            if isinstance(obj, (str, unicode, basestring)):
                obj = MultiDict(json.loads(obj))
        if isinstance(obj, (dict, list)) and not isinstance(obj, MultiDict):
            return obj
        if isinstance(obj, MultiValueDict):
            obj = MultiDict(six.iteritems(obj))
        result = dict()

        convert_funs = {
            'integer': lambda v: self.validate_number(int, v[0]),
            'boolean': lambda v: v[0].lower() not in ['n', 'no', 'false', '', '0'],
            'null': lambda v: None,
            'number': lambda v: self.validate_number(float, v[0]),
            'string': lambda v: v[0]
        }

        def convert_array(type_, v):
            func = convert_funs.get(type_, lambda v: v[0])
            return [func([i]) for i in v]

        for k, values in obj.lists():
            prop = self.validator.schema['properties'].get(k, {})
            type_ = prop.get('type')
            fun = convert_funs.get(type_, lambda v: v[0])
            if type_ == 'array':
                item_type = prop.get('items', {}).get('type')
                result[k] = convert_array(item_type, values)
            else:
                result[k] = fun(values)
        return result

    def validate(self, value):
        value = self.type_convert(value)
        errors = list(e.message for e in self.validator.iter_errors(value))
        return normalize(self.validator.schema, value)[0], errors

def request_validate(view):
    @wraps(view)
    def wrapper(request, *args, **kwargs):
        endpoint = request.resolver_match.kwargs.get('endpoint')
        method = request.method
        # scope
        security.current_request = request
        if (endpoint, request.method) in scopes and not set(
                scopes[(endpoint, request.method)]).issubset(set(security.scopes)):
            return HttpResponseForbidden(status=403)
        security.current_request = None
        if method == 'HEAD':
            method = 'GET'
        locations = validators.get((endpoint, method), {})
        for location, schema in six.iteritems(locations):
            if location == 'json':
                value = getattr(request, 'json', MultiDict())
            elif location == 'args':
                value = getattr(request, 'args', MultiDict())
                for k,v in six.iteritems(value):
                    if isinstance(v, list) and len(v) == 1:
                        value[k] = v[0]
                value = MultiDict(value)
            else:
                value = getattr(request, location, MultiDict())
            validator = ValidatorAdaptor(schema)
            result, reasons = validator.validate(value)
            if reasons:
                return HttpResponse(status=422, reason='Unprocessable Entity',
                                    content_type='application/json', content=json.dumps(reasons))
            setattr(request, location, result)
        return view(request, *args, **kwargs)
    return wrapper


def response_filter(view):
    @wraps(view)
    def wrapper(request, *args, **kwargs):
        resp = view(request, *args, **kwargs)
        endpoint = request.resolver_match.kwargs.get('endpoint')
        method = request.method
        if method == 'HEAD':
            method = 'GET'
        headers = None
        status = None
        if isinstance(resp, tuple):
            resp, status, headers = unpack(resp)
        filter = filters.get((endpoint, method), None)
        if filter:
            if len(filter) == 1:
                if six.PY3:
                    status = list(filter.keys())[0]
                else:
                    status = filter.keys()[0]

            schemas = filter.get(status)
            if not schemas:
                # return resp, status, headers
                return HttpResponse(status=500, reason='`%d` is not a defined status code.' % status,
                                    content_type='application/json')

            resp, errors = normalize(schemas['schema'], resp)
            if schemas['headers']:
                headers, header_errors = normalize(
                    {'properties': schemas['headers']}, headers)
                errors.extend(header_errors)
            if errors:
                return HttpResponse(status=500,
                                    content=json.dumps(errors),
                                    reason='Expectation Failed',
                                    content_type='application/json')
        resp_obj = HttpResponse(json.dumps(resp), status=status, content_type='application/json')
        if headers:
            if isinstance(headers, (list, tuple)):
                _items = headers
            elif isinstance(headers, dict):
                _items = headers.items()
            else:
                _items = []
            for _h, _v in _items:
                resp_obj[_h] = _v
        return resp_obj
    return wrapper


def unpack(value):
    if not isinstance(value, tuple):
        return value, 200, {}

    try:
        data, code, headers = value
        return data, code, headers
    except ValueError:
        pass

    try:
        data, code = value
        return data, code, {}
    except ValueError:
        pass

    return value, 200, {}