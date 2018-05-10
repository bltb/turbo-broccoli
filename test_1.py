#!/usr/bin/env python

import coloredlogs, logging


logger = logging.getLogger(__name__)
coloredlogs.install(level='DEBUG', logger=logger, isatty=True)

logger.debug("this is a debugging message")
logger.info("this is an informational message")


