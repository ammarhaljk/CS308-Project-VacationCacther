import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'dart:async';

class TripPlannerScreen extends StatefulWidget {
  final String userId;

  TripPlannerScreen({required this.userId});

  @override
  _TripPlannerScreenState createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _createNewTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(userId: widget.userId),
      ),
    );
  }

  void _acceptTripInvite(String tripId, String inviteId, String tripName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Update invite status
      await FirebaseFirestore.instance
          .collection('tripInvites')
          .doc(inviteId)
          .update({'status': 'accepted'});

      // Add user to trip participants
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('participants')
          .doc(widget.userId)
          .set({
        'userId': widget.userId,
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'accepted',
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You've joined the trip: $tripName")),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error accepting invite: ${e.toString()}")),
      );
    }
  }

  void _rejectTripInvite(String inviteId, String tripName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      await FirebaseFirestore.instance
          .collection('tripInvites')
          .doc(inviteId)
          .update({'status': 'rejected'});

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trip invite for $tripName rejected")),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error rejecting invite: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFF5252),
        title: Text(
          "Trip Planner",
          style: GoogleFonts.pacifico(fontSize: 24, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: "My Trips"),
            Tab(text: "Invites"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyTripsTab(),
          _buildInvitesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewTrip,
        backgroundColor: Color(0xFFFF5252),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMyTripsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('creatorId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, createdTripsSnapshot) {
        if (createdTripsSnapshot.hasError) {
          return Center(child: Text("Something went wrong"));
        }

        if (createdTripsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final createdTrips = createdTripsSnapshot.data?.docs ?? [];

        // Also get trips where user accepted invites
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tripInvites')
              .where('inviteeId', isEqualTo: widget.userId)
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, acceptedInvitesSnapshot) {
            if (acceptedInvitesSnapshot.hasError) {
              return Center(child: Text("Something went wrong"));
            }

            if (acceptedInvitesSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final acceptedInvites = acceptedInvitesSnapshot.data?.docs ?? [];
            final acceptedTripIds = acceptedInvites.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['tripId'] as String;
            }).toList();

            if (acceptedTripIds.isEmpty) {
              // Only show created trips
              return _buildTripsList(createdTrips, []);
            }

            // Get the actual trip documents for accepted invites
            return StreamBuilder<QuerySnapshot>(
              stream: acceptedTripIds.isEmpty
                  ? Stream.value(QuerySnapshot as QuerySnapshot)
                  : FirebaseFirestore.instance
                  .collection('trips')
                  .where(FieldPath.documentId, whereIn: acceptedTripIds.take(10).toList())
                  .snapshots(),
              builder: (context, acceptedTripsSnapshot) {
                final acceptedTrips = acceptedTripsSnapshot.data?.docs ?? [];
                return _buildTripsList(createdTrips, acceptedTrips);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTripsList(List<QueryDocumentSnapshot> createdTrips, List<QueryDocumentSnapshot> acceptedTrips) {
    final allTrips = <Map<String, dynamic>>[];

    // Add created trips
    for (final trip in createdTrips) {
      final tripData = trip.data() as Map<String, dynamic>;
      allTrips.add({
        'id': trip.id,
        'data': tripData,
        'isCreator': true,
      });
    }

    // Add accepted trips
    for (final trip in acceptedTrips) {
      final tripData = trip.data() as Map<String, dynamic>;
      allTrips.add({
        'id': trip.id,
        'data': tripData,
        'isCreator': false,
      });
    }

    if (allTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No trips planned yet",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              "Tap the + button to create your first trip",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort trips by creation date (most recent first)
    allTrips.sort((a, b) {
      final aDate = a['data']['createdAt'] as Timestamp?;
      final bDate = b['data']['createdAt'] as Timestamp?;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: allTrips.length,
      itemBuilder: (context, index) {
        final tripInfo = allTrips[index];
        final tripData = tripInfo['data'] as Map<String, dynamic>;
        final tripId = tripInfo['id'] as String;
        final isCreator = tripInfo['isCreator'] as bool;

        final tripName = tripData['tripName'] as String;
        final destination = tripData['destination'] as String;
        final meetingPoint = tripData['meetingPoint'] as String;
        final meetingDate = (tripData['meetingDate'] as Timestamp).toDate();
        final meetingTime = tripData['meetingTime'] as String;

        return GestureDetector(
          onLongPress: () => _showTripAttractionsDialog(tripId, tripName),
          child: Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flight_takeoff, color: Color(0xFFFF5252)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tripName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!isCreator)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            'Participant',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildTripDetailRow(Icons.location_on, "Destination", destination),
                  SizedBox(height: 8),
                  _buildTripDetailRow(Icons.meeting_room, "Meeting Point", meetingPoint),
                  SizedBox(height: 8),
                  _buildTripDetailRow(Icons.calendar_today, "Date",
                      "${meetingDate.day}/${meetingDate.month}/${meetingDate.year}"),
                  SizedBox(height: 8),
                  _buildTripDetailRow(Icons.access_time, "Time", meetingTime),
                  SizedBox(height: 12),
                  // Long press hint
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF5252).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 14, color: Color(0xFFFF5252)),
                        SizedBox(width: 4),
                        Text(
                          "Long press to manage attractions/places to visit",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF5252),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _viewTripParticipants(tripId, tripName),
                        icon: Icon(Icons.people, color: Color(0xFFFF5252)),
                        label: Text("View Participants", style: TextStyle(color: Color(0xFFFF5252))),
                      ),
                      if (isCreator)
                        TextButton.icon(
                          onPressed: () => _editTrip(tripId, tripData),
                          icon: Icon(Icons.edit, color: Colors.grey),
                          label: Text("Edit", style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _getTripsById(List<String> tripIds) async {
    if (tripIds.isEmpty) return [];

    final List<DocumentSnapshot> trips = [];

    // Firestore 'in' queries are limited to 10 items, so we need to batch them
    for (int i = 0; i < tripIds.length; i += 10) {
      final batch = tripIds.skip(i).take(10).toList();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      trips.addAll(querySnapshot.docs);
    }

    return trips;
  }

  Widget _buildInvitesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tripInvites')
          .where('inviteeId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final invites = snapshot.data?.docs ?? [];

        if (invites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No pending trip invites",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(8),
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final inviteData = invites[index].data() as Map<String, dynamic>;
            final inviteId = invites[index].id;
            final tripId = inviteData['tripId'] as String;
            final tripName = inviteData['tripName'] as String;
            final destination = inviteData['destination'] as String;
            final creatorName = inviteData['creatorName'] as String;
            final meetingDate = (inviteData['meetingDate'] as Timestamp).toDate();
            final meetingTime = inviteData['meetingTime'] as String;

            return Card(
              elevation: 4,
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(0xFFFF7043),
                          child: Text(
                            creatorName[0].toUpperCase(),
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$creatorName invited you to:",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              Text(
                                tripName,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildTripDetailRow(Icons.location_on, "Destination", destination),
                    SizedBox(height: 8),
                    _buildTripDetailRow(Icons.calendar_today, "Date",
                        "${meetingDate.day}/${meetingDate.month}/${meetingDate.year}"),
                    SizedBox(height: 8),
                    _buildTripDetailRow(Icons.access_time, "Time", meetingTime),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _acceptTripInvite(tripId, inviteId, tripName),
                            icon: Icon(Icons.check, color: Colors.white),
                            label: Text("Accept", style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _rejectTripInvite(inviteId, tripName),
                            icon: Icon(Icons.close, color: Colors.white),
                            label: Text("Decline", style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTripDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  void _viewTripParticipants(String tripId, String tripName) {
    // Navigate to participants screen or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$tripName Participants"),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('trips')
                .doc(tripId)
                .collection('participants')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final participants = snapshot.data!.docs;

              if (participants.isEmpty) {
                return Center(child: Text("No participants yet"));
              }

              return ListView.builder(
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participantData = participants[index].data() as Map<String, dynamic>;
                  final userId = participants[index].id;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return ListTile(title: Text("Loading..."));
                      }

                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      final username = userData?['username'] ?? 'Unknown User';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFFFF7043),
                          child: Text(username[0].toUpperCase()),
                        ),
                        title: Text(username),
                        trailing: Icon(Icons.check_circle, color: Colors.green),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  void _editTrip(String tripId, Map<String, dynamic> tripData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(
          userId: widget.userId,
          tripId: tripId,
          existingTripData: tripData,
        ),
      ),
    );
  }

  void _showTripAttractionsDialog(String tripId, String tripName) {
    final TextEditingController _attractionController = TextEditingController();
    final FocusNode _focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFFFF5252)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$tripName - Places",
                  style: TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // Add new attraction section
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _attractionController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: "Add a place or attraction...",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _addAttraction(tripId, value.trim());
                            _attractionController.clear();
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (_attractionController.text.trim().isNotEmpty) {
                          _addAttraction(tripId, _attractionController.text.trim());
                          _attractionController.clear();
                        }
                      },
                      icon: Icon(Icons.add, color: Color(0xFFFF5252)),
                      style: IconButton.styleFrom(
                        backgroundColor: Color(0xFFFF5252).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 16),

                // Attractions list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('trips')
                        .doc(tripId)
                        .collection('attractions')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error loading attractions"));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final attractions = snapshot.data?.docs ?? [];

                      if (attractions.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.explore_off, size: 60, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                "No places added yet",
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Add places and attractions to visit!",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: attractions.length,
                        itemBuilder: (context, index) {
                          final attractionDoc = attractions[index];
                          final attractionData = attractionDoc.data() as Map<String, dynamic>;
                          final attractionId = attractionDoc.id;
                          final name = attractionData['name'] as String;
                          final isCompleted = attractionData['isCompleted'] as bool? ?? false;
                          final addedBy = attractionData['addedBy'] as String? ?? 'Unknown';

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Checkbox(
                                value: isCompleted,
                                activeColor: Color(0xFFFF5252),
                                onChanged: (bool? value) {
                                  _toggleAttractionStatus(tripId, attractionId, value ?? false);
                                },
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: isCompleted ? Colors.grey : Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                "Added by $addedBy",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteAttraction(tripId, attractionId, name),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _focusNode.unfocus();

                // Small delay to let the keyboard close
                Future.delayed(Duration(milliseconds: 100), () {
                  _attractionController.dispose();
                  _focusNode.dispose(); // Don't forget to dispose the FocusNode
                  Navigator.pop(context);
                });
              },
              child: Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAttraction(String tripId, String attractionName) async {
    try {
      // Get current user info
      final currentUser = _authService.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? currentUser.email!.split('@')[0];

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('attractions')
          .add({
        'name': attractionName,
        'isCompleted': false,
        'addedBy': username,
        'addedById': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error handling without SnackBar
      print("Error adding attraction: ${e.toString()}");
    }
  }

  Future<void> _toggleAttractionStatus(String tripId, String attractionId, bool isCompleted) async {
    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('attractions')
          .doc(attractionId)
          .update({
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      print("Error updating attraction: ${e.toString()}");
    }
  }

  Future<void> _deleteAttraction(String tripId, String attractionId, String attractionName) async {
    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Attraction"),
        content: Text("Are you sure you want to delete '$attractionName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .collection('attractions')
            .doc(attractionId)
            .delete();
      } catch (e) {
        print("Error deleting attraction: ${e.toString()}");
      }
    }
  }
}

class CreateTripScreen extends StatefulWidget {
  final String userId;
  final String? tripId;
  final Map<String, dynamic>? existingTripData;

  CreateTripScreen({
    required this.userId,
    this.tripId,
    this.existingTripData,
  });

  @override
  _CreateTripScreenState createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _tripNameController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _meetingPointController = TextEditingController();
  final TextEditingController _meetingTimeController = TextEditingController();

  DateTime? _selectedDate;
  List<Map<String, dynamic>> _selectedFriends = [];
  List<Map<String, dynamic>> _availableFriends = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();

    if (widget.existingTripData != null) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final data = widget.existingTripData!;
    _tripNameController.text = data['tripName'] ?? '';
    _destinationController.text = data['destination'] ?? '';
    _meetingPointController.text = data['meetingPoint'] ?? '';
    _meetingTimeController.text = data['meetingTime'] ?? '';

    if (data['meetingDate'] != null) {
      _selectedDate = (data['meetingDate'] as Timestamp).toDate();
    }
  }

  void _loadFriends() async {
    try {
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .get();

      final friends = await Future.wait(
        friendsSnapshot.docs.map((doc) async {
          final friendData = doc.data();
          return {
            'id': doc.id,
            'username': friendData['username'],
            'email': friendData['email'],
          };
        }),
      );

      setState(() {
        _availableFriends = friends;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading friends: ${e.toString()}")),
      );
    }
  }

  void _selectFriends() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Select Friends"),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: _availableFriends.isEmpty
              ? Center(child: Text("No friends available"))
              : ListView.builder(
            itemCount: _availableFriends.length,
            itemBuilder: (context, index) {
              final friend = _availableFriends[index];
              final isSelected = _selectedFriends.any((f) => f['id'] == friend['id']);

              return CheckboxListTile(
                title: Text(friend['username']),
                subtitle: Text(friend['email']),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedFriends.add(friend);
                    } else {
                      _selectedFriends.removeWhere((f) => f['id'] == friend['id']);
                    }
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Done"),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _meetingTimeController.text = picked.format(context);
      });
    }
  }

  void _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a meeting date")),
      );
      return;
    }
    if (_meetingTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a meeting time")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _authService.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final creatorName = userData['username'] ?? currentUser.email!.split('@')[0];

      final tripData = {
        'tripName': _tripNameController.text.trim(),
        'destination': _destinationController.text.trim(),
        'meetingPoint': _meetingPointController.text.trim(),
        'meetingDate': Timestamp.fromDate(_selectedDate!),
        'meetingTime': _meetingTimeController.text.trim(),
        'creatorId': widget.userId,
        'creatorName': creatorName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String tripId;
      if (widget.tripId != null) {
        // Update existing trip
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .update(tripData);
        tripId = widget.tripId!;
      } else {
        // Create new trip
        final docRef = await FirebaseFirestore.instance
            .collection('trips')
            .add(tripData);
        tripId = docRef.id;

        // Add creator as participant
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .collection('participants')
            .doc(widget.userId)
            .set({
          'userId': widget.userId,
          'joinedAt': FieldValue.serverTimestamp(),
          'status': 'creator',
        });
      }

      // Send invites to selected friends (only for new trips or if friends selection changed)
      if (widget.tripId == null) {
        for (final friend in _selectedFriends) {
          await FirebaseFirestore.instance.collection('tripInvites').add({
            'tripId': tripId,
            'tripName': _tripNameController.text.trim(),
            'destination': _destinationController.text.trim(),
            'meetingDate': Timestamp.fromDate(_selectedDate!),
            'meetingTime': _meetingTimeController.text.trim(),
            'creatorId': widget.userId,
            'creatorName': creatorName,
            'inviteeId': friend['id'],
            'inviteeName': friend['username'],
            'inviteeEmail': friend['email'],
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.tripId != null
            ? "Trip updated successfully"
            : "Trip created and invites sent!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving trip: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFF5252),
        title: Text(
          widget.tripId != null ? "Edit Trip" : "Create New Trip",
          style: GoogleFonts.pacifico(fontSize: 20, color: Colors.white),
        ),
        actions: [
          if (_isLoading)
            Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ))
          else
            TextButton(
              onPressed: _saveTrip,
              child: Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tripNameController,
              decoration: InputDecoration(
                labelText: "Trip Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flight_takeoff),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a trip name';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: "Destination",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a destination';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _meetingPointController,
              decoration: InputDecoration(
                labelText: "Meeting Point",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a meeting point';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Meeting Date",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _selectedDate != null
                      ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                      : "Select date",
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),

            InkWell(
              onTap: _selectTime,
              child: TextFormField(
                controller: _meetingTimeController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "Meeting Time",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                  suffixIcon: Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ),
            SizedBox(height: 16),

            if (widget.tripId == null) ...[
              Card(
                child: ListTile(
                  leading: Icon(Icons.people),
                  title: Text("Select Friends to Invite"),
                  subtitle: Text(_selectedFriends.isEmpty
                      ? "No friends selected"
                      : "${_selectedFriends.length} friend(s) selected"),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: _selectFriends,
                ),
              ),
              SizedBox(height: 16),

              if (_selectedFriends.isNotEmpty) ...[
                Text("Selected Friends:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _selectedFriends.map((friend) => Chip(
                    label: Text(friend['username']),
                    onDeleted: () {
                      setState(() {
                        _selectedFriends.removeWhere((f) => f['id'] == friend['id']);
                      });
                    },
                  )).toList(),
                ),
                SizedBox(height: 16),
              ],
            ],

            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF5252),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                widget.tripId != null ? "UPDATE TRIP" : "CREATE TRIP",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _destinationController.dispose();
    _meetingPointController.dispose();
    _meetingTimeController.dispose();
    super.dispose();
  }
}