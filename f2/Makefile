default: 
	echo "Placing flag into /tmp/${FLAG} on ${MACHINE}"
	make check > /tmp/${FLAG}

check:
	echo "SOME RANDOM SALT AND STUDENT SPECIFICS ${FLAG} ${MACHINE}" | sha256sum | cut -d" " -f1

clean:
	rm /tmp/f2 && echo "Removed /tmp/f2"
