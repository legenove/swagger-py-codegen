# -*- coding: utf-8 -*-
import json

try:
	from django.utils.deprecation import MiddlewareMixin
except ImportError:
	MiddlewareMixin = object


class SchemaMiddleware(MiddlewareMixin):
	def process_request(self, request):
		method = request.method
		if method == 'HEAD':
			method = 'GET'
		request.args = request.GET
		if request.content_type == 'application/json':
			try:
				request.json = json.loads(request.body)
			except:
				request.json = {}
		if request.POST and request.content_type != 'application/json':
			request.json = request.POST