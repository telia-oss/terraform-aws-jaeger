import logging
import os
import urllib3
import json
import re
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)
pm = urllib3.PoolManager()

# Check if the required envvars are set
retention = None
try:
    retention = datetime.timedelta(
        int(os.environ['ES_RETENTION_DAYS'])
    )
except Exception as e:
    logging.error('Error with ES_RETENTION_DAYS environment variable: {}'.format(e))

elasticsearch = None
try:
    elasticsearch = os.environ['ES_HOSTNAME']
except Exception as e:
    logging.error('Error with ES_HOSTNAME environment variable: {}'.format(e))


def lambda_handler(event, context):

    # Get a list of all indices in the cluster
    indices = None
    try:
        indices = pm.request(
            'GET',
            'https://' + elasticsearch + '/_cat/indices?format=json'
        )
        indices = json.loads(indices.data)
    except Exception as e:
        logger.error('Failed to get the list of indices: {}'.format(e))

    # Select the indices we are doing to delete
    indices_to_delete = []
    for index in indices:
        if re.match('^jaeger-', index['index']):
            timestamp = re.sub('^[^0-9]*','', index['index'])
            timestamp = datetime.date.fromisoformat(timestamp)
            if timestamp < datetime.date.today() - retention:
                indices_to_delete.append(index['index'])

    indices_to_delete.sort()
    logger.info('Selected the following indices to delete: {}'.format(indices_to_delete))

    # Delete selected indices
    for index in indices_to_delete:
        try:
            delete_request = pm.request(
                'DELETE',
                'https://' + elasticsearch + '/' + index
            )
            if delete_request.status != 200:
                logger.error('Error from ES while deleting index "{}": {}'.format(index, delete_request.data))
        except Exception as e:
            logger.error('Failed to delete index "{}": {}'.format(index, e))

    return {'statusCode': 200}
