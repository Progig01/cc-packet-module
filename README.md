# Computercraft Packet Module

This is a very unoriginally named module for making better networking in Computercraft.

## Installation

To "install", simply download module.lua and put it somewhere on the computer.

## Usage

```lua
packet = dofile('module.lua')
packet:openRednet()

myPacket = packet:newPacket()
myPacket:send()

receivedPacket = packet:receive()
print(receivedPacket.data)
```

## Planned features

 -Some kind of encryption, might implement SHA-2
 -Implementing handshaking to ensure that the desired recipient is available before sending it a packet
 -More features for packet clusters; bulk filtered sending, bulk filtered deleting, etc
 -Routing optimization
 -Modules built off of this one, like an FTP-esque file-server and client

 I'm also always open to suggestions. See the next section for contact details if you don't feel like emailing me.

## Contributing

Feel free to make pull requests, if I don't accept them quickly, feel free to email me or message me on discord @Progig#1548 or on the Computercraft/Opencomputers [Discord](https://discord.gg/H2UyJXe)

## License
[MIT](https://choosealicense.com/licenses/mit/)