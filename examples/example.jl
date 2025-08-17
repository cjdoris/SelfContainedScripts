# /// project
# name = "example"
# 
# [deps]
# Example = "7876af07-990d-54b4-ab0e-23690620f79a"
# ///

using SelfContainedScripts
SelfContainedScripts.activate()

using Example
@show Example.hello("Alice")
