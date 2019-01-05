default:
	echo "Placing flag into /tmp/${FLAG} on ${MACHINE}"
	echo "Placing flag into /tmp/${FLAG} on ${MACHINE}" | sha256sum | cut -d" " -f1 > /tmp/f2

check:
	echo "Placing flag into /tmp/${FLAG} on ${MACHINE}" | sha256sum | cut -d" " -f1

clean:
	rm /tmp/f2 && echo "Removed /tmp/f2"
