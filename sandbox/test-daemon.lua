require("alua")

alua.create("127.0.0.1", 11111)
print(alua.id)
alua.loop()
