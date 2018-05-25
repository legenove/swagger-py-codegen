# -*- coding: utf-8 -*-
from __future__ import absolute_import

from .validators import security

@security.scopes_loader
def current_scopes():
    return {{ scopes_supported }}