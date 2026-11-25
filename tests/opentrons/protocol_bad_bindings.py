# A binding file that defines names it must not define, uses constructors and
# operations the compiled program does not declare, and defines no setup; the
# names of the class body are not top-level names, and those of comments and
# string literals are not used.

import os as _tempore_os
from os.path import join as tempore_join

tempore_count = 0
metadata = {}


def run(protocol):
    pass


def probe_0(ctx, arg):
    return arg


class Deck:
    def tempore_method(self):
        tempore_local = 0
        return tempore_local


def values(ctx, arg):
    # tempore_con_Comment
    text = "tempore_con_String \" tempore_op_String"
    block = """tempore_op_Block
    tempore_con_Block"""
    return (tempore_con_Some(arg), tempore_op_Pipette, text, block,
            tempore_con_Missing(), tempore_op_Missing, tempore_con_Missing())
