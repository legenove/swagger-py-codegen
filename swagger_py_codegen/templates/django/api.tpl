# -*- coding: utf-8 -*-
from __future__ import absolute_import

from django.views.generic import View
from django.utils.decorators import method_decorator

from ..validators import request_validate, response_filter


class RequestView(View):

	@method_decorator(response_filter)
	@method_decorator(request_validate)
	def dispatch(self, request, *args, **kwargs):
		return super(RequestView, self).dispatch(request, *args, **kwargs)
