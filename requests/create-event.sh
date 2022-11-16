http \
  --ignore-stdin \
  -a ${LOOM_USERNAME}:${LOOM_PASSWORD} \
  POST \
  "${LOOM_URL}/api/events" \
	specversion=1.0 \
	type=com.example.someevent \
	source=test-source \
	id=12 \
	time=2018-04-05T17:31:00Z \
	comexampleextension1=value \
	comexampleothervalue:=5 \
	unsetextension:=null \
	datacontenttype=application/xml \
	data='<much wow=\"xml\"/>'
