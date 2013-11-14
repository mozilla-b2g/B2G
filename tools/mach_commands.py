# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

from __future__ import print_function, unicode_literals

import mozfile
import os

from mach.decorators import (
    CommandProvider,
    Command,
)
from mozbuild.base import (
    MachCommandBase,
    MachCommandConditions as conditions
)

@CommandProvider
class Build(MachCommandBase):
    """Interface for build related commands."""

    def __init__(self, context):
        MachCommandBase.__init__(self, context)
        self.b2g_home = context.b2g_home

    @Command('clobber', category='build',
        conditions=[conditions.is_b2g],
        description='Clobber the tree (delete the objdir and out directory).')
    def clobber(self):
        self.remove_objdir()
        outdir = os.path.join(self.b2g_home, 'out')
        if os.path.isdir(outdir):
            mozfile.rmtree(outdir)
        return 0
