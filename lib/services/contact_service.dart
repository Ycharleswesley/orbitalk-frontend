import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches contacts from the device and normalizes their phone numbers.
  Future<List<Contact>> fetchDeviceContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      debugPrint('ContactService: Permission denied');
      return [];
    }

    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      return contacts.where((c) => c.phones.isNotEmpty).toList();
    } catch (e) {
      debugPrint('ContactService: Error fetching contacts: $e');
      return [];
    }
  }

  /// Normalizes phone number to E.164 format (simplified for matching).
  /// Removes spaces, dashes, parentheses.
  /// If logic gets complex (country codes), we might need `libphonenumber` later.
  /// For now, we strip non-digits.
  String normalizePhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    // Ensure it has a country code if possible, or leave it for loose matching
    // Ideally, Firestore stores E.164 (e.g., +919988776655)
    return cleaned;
  }

  /// Matches device contacts with registered users in Firestore.
  /// Returns a Map with 'registered' (List<Map>) and 'unregistered' (List<Contact>).
  Future<Map<String, List<dynamic>>> matchContactsWithUsers(List<Contact> deviceContacts) async {
    List<Map<String, dynamic>> registeredUsers = [];
    List<Contact> unregisteredContacts = [];

    // 1. Extract and normalize all phone numbers from device contacts
    //    We store a map of {normalizedNumber: Contact} to map back later
    Map<String, Contact> phoneToContactMap = {};
    
    for (var contact in deviceContacts) {
      for (var phone in contact.phones) {
        String normalized = normalizePhoneNumber(phone.number);
        if (normalized.length >= 10) { // Basic validity check
           // Store mapping. Note: One contact might have multiple numbers.
           // We map the number to the contact.
           phoneToContactMap[normalized] = contact;
           
           // Also try matching without country code (last 10 digits) if local processing needed
           // but for Firestore query, we usually need exact match or consistent format.
        }
      }
    }

    List<String> allPhoneNumbers = phoneToContactMap.keys.toList();

    // 2. Batch query Firestore (chunk of 10 for 'whereIn')
    //    Firestore 'whereIn' supports up to 10 values by default in older SDKs, or 30 in newer.
    //    We'll stick to 10 to be safe and broadly compatible.
    int chunkSize = 10;
    
    // We will query by 'phoneNumber' field in 'users' collection
    for (var i = 0; i < allPhoneNumbers.length; i += chunkSize) {
      List<String> chunk = allPhoneNumbers.sublist(
        i, 
        i + chunkSize > allPhoneNumbers.length ? allPhoneNumbers.length : i + chunkSize
      );

      if (chunk.isEmpty) continue;

      try {
        final querySnapshot = await _firestore
            .collection('users')
            .where('phoneNumber', whereIn: chunk)
            .get();

        for (var doc in querySnapshot.docs) {
          final userData = doc.data();
          userData['uid'] = doc.id; // Ensure UID is included
          registeredUsers.add(userData);
          
          // Remove from map so we know who is left as "unregistered"
          // We need to find which normalized number matched.
          // The doc['phoneNumber'] should match one in our chunk.
          String? matchedPhone = userData['phoneNumber'];
          if (matchedPhone != null) {
              // Try to find the original contact key that matches this
              // Pass 1: Exact match
              if (phoneToContactMap.containsKey(matchedPhone)) {
                  phoneToContactMap.remove(matchedPhone);
              }
          }
        }
      } catch (e) {
        debugPrint('ContactService: Error querying chunk: $e');
      }
    }

    // 3. Remaining items in phoneToContactMap are unregistered
    //    We need to deduplicate because one contact might have 2 numbers, 
    //    one registered, one not. If one is registered, we treat the person as registered generally?
    //    Or show them as registered based on that number.
    //    User asked: "if i wanna talk to the new user and he is not using the app... u direct me to his messages"
    //    So simpler is: If ANY number of a contact matches, they are Registered.
    //    If NO number matches, they are Unregistered.
    
    //    The `registeredUsers` list contains the user profiles.
    //    Now we define `unregisteredContacts`.
    
    //    We iterate through original deviceContacts. 
    //    If a contact was NOT found in registeredUsers (by checking if any of their phones matched), add to unregistered.
    
    Set<String> registeredPhoneNumbers = registeredUsers.map((u) => u['phoneNumber'] as String).toSet();
    
    for (var contact in deviceContacts) {
        bool isRegistered = false;
        for (var phone in contact.phones) {
            String normalized = normalizePhoneNumber(phone.number);
            if (registeredPhoneNumbers.contains(normalized)) {
                isRegistered = true;
                break;
            }
        }
        
        if (!isRegistered) {
            unregisteredContacts.add(contact);
        }
    }

    return {
      'registered': registeredUsers,
      'unregistered': unregisteredContacts,
    };
  }
}
