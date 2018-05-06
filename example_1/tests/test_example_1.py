#!/usr/bin/env python

import example_1

test_ids = [{'id': 3}, {'id': 1}]
test_ids_2 = [{'status': 'completed'}, {'status': 'running'}]

def test_something():
    print(test_ids)
    print(example_1.get_maximum_id(test_ids))

def test_get_completed():
    print(example_1.get_completed(test_ids_2))
