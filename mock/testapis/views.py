from django.views.decorators.csrf import csrf_exempt

from testapis import response


@csrf_exempt
def crud(request):

    if request.method == 'POST':
        return response.success_response("Call POST API")
    if request.method == 'GET':
        return response.success_response("Call GET API")
    if request.method == 'PUT':
        return response.success_response("Call PUT API")
    if request.method == 'DELETE':
        return response.success_response("Call DELETE API")
