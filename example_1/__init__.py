#!/usr/bin/env python
'''blah'''

import json
from operator import itemgetter

JSON_1_SORTED = '''
{
    "a": [
    {"status": "cancelled", "id": "1", "v": "x"},
    {"status": "completed", "id": "2", "v": "z"},
    {"status": "completed", "id": "3", "v": "y"}
    ]
}
'''

JSON_1_UNSORTED = '''
{
    "a": [
    {"status": "cancelled", "id": "1", "v": "x"},
    {"status": "completed", "id": "3", "v": "y"},
    {"status": "completed", "id": "2", "v": "z"}
    ]
}
'''


def get_completed(mixed_statuses):
    '''get_completed'''
    return list(filter(lambda d: d["status"] in ['completed'], mixed_statuses))


def get_maximum_id(ids):
    '''get_maximum_id'''
    # how slow is this?
    # do we really need to sort?
    return sorted(ids, key=itemgetter('id'))[-1]
    # return sorted(ids, key=itemgetter('id'), reverse=True)[0]
    # print(newlist)
    # print(newlist[0])

def main():
    '''main'''
    jstatus = json.loads(JSON_1_UNSORTED)
    # print(d)
    only_completed = get_completed(jstatus['a'])
    print(only_completed)
    print(get_maximum_id(only_completed))

    print(jstatus['a'])


if __name__ == "__main__":
    # execute only if run as a script
    main()

# vim: ft=python
